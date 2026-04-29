/**********************************************************************************
 * ICB_FirmaDigitalFlowAction
 * Acción invocable desde Flow: envía PDF a TuFirma y crea Contrato_Digital__c.
 * SEIDOR - RCG - Integración Firma Digital TuFirma/AWS
 **********************************************************************************/
public with sharing class ICB_FirmaDigitalFlowAction {

    // Picklist Estado__c en Contrato_Digital__c debe tener estos valores
    private static final String ESTADO_ENVIADO = 'Enviado';
    private static final String ESTADO_ERROR = 'Rechazado';

    public class InvocableInput {
        @InvocableVariable(required=true label='Quote Id')
        public String quoteId;
        @InvocableVariable(required=true label='PDF en base64')
        public String pdfBase64;
        @InvocableVariable(label='Nombre del archivo PDF')
        public String pdfFileName;
    }

    public class InvocableOutput {
        @InvocableVariable(label='Éxito')
        public Boolean success;
        @InvocableVariable(label='Id Contrato Digital')
        public String contratoDigitalId;
        @InvocableVariable(label='Contrato Id (TuFirma)')
        public String contratoId;
        @InvocableVariable(label='Mensaje de error')
        public String errorMessage;
    }

    @InvocableMethod(label='Enviar PDF a Firma Digital desde Quote' description='Envia PDF a TuFirma y crea Contrato_Digital__c' callout=true)
    public static List<InvocableOutput> enviarPdfAFirmaDigital(List<InvocableInput> inputs) {
        List<InvocableOutput> outputs = new List<InvocableOutput>();
        for (InvocableInput input : inputs) {
            outputs.add(procesarUno(input));
        }
        return outputs;
    }

    private static InvocableOutput procesarUno(InvocableInput input) {
        InvocableOutput out = new InvocableOutput();
        out.success = false;
        out.contratoDigitalId = null;
        out.contratoId = null;
        out.errorMessage = null;

        if (String.isBlank(input.quoteId) || String.isBlank(input.pdfBase64)) {
            out.errorMessage = 'Quote Id y PDF en base64 son obligatorios.';
            return out;
        }

        try {
            Id qId = (Id) input.quoteId;

            Quote q = obtenerQuote(qId);
            if (q == null || q.ContactId == null) {
                out.errorMessage = 'La Quote no tiene Contact (ContactId) asociado.';
                return out;
            }
            if (q.Contact == null) {
                out.errorMessage = 'No se pudo obtener el Contact asociado a la Quote.';
                return out;
            }
            Contact con = q.Contact;

            String base64Raw = quitarPrefijoDataUrl(input.pdfBase64);
            Blob pdfBody = EncodingUtil.base64Decode(base64Raw);
            if (pdfBody == null || pdfBody.size() == 0) {
                out.errorMessage = 'El PDF en base64 está vacío o no es válido.';
                return out;
            }

            String fileName = String.isNotBlank(input.pdfFileName) ? input.pdfFileName : 'documento.pdf';
            if (!fileName.endsWithIgnoreCase('.pdf')) {
                fileName += '.pdf';
            }

            String contratoIdExternal = 'FD-' + (String.isNotBlank(q.QuoteNumber) ? q.QuoteNumber : String.valueOf(qId).left(15));

            ICB_FirmaDigitalServiceImpl.UploadRequestDto req = new ICB_FirmaDigitalServiceImpl.UploadRequestDto();
            req.contratoId = contratoIdExternal;
            req.fileName = fileName;
            req.signatureConfig = new ICB_FirmaDigitalServiceImpl.SignatureConfigDto();
            req.signatureConfig.nombre = String.isNotBlank(q.Name) ? q.Name : 'Contrato';
            req.signatureConfig.firmantes = new List<ICB_FirmaDigitalServiceImpl.FirmanteDto>();
            ICB_FirmaDigitalServiceImpl.FirmanteDto firmante = new ICB_FirmaDigitalServiceImpl.FirmanteDto();
            firmante.nombre = con.Name;
            firmante.email = String.isNotBlank(con.Email) ? con.Email : null;
            firmante.rut = con.RUT__c;
            firmante.telefono = String.isNotBlank(con.MobilePhone) ? con.MobilePhone : null;
            req.signatureConfig.firmantes.add(firmante);

            ICB_FirmaDigitalServiceImpl.UploadResponseDto uploadRes = ICB_FirmaDigitalServiceImpl.solicitarUploadUrl(req);
            ICB_FirmaDigitalServiceImpl.subirPdfAUploadUrl(uploadRes.uploadUrl, pdfBody);

            Contrato_Digital__c contrato = crearContratoDigital(
                qId, uploadRes.contratoId, null, null, null,
                con.Name, con.Email, con.MobilePhone, DateTime.now(), null, null
            );
            insert contrato;

            update new Quote(Id = qId, Contrato_Digital__c = contrato.Id);

            out.success = true;
            out.contratoDigitalId = contrato.Id;
            out.contratoId = uploadRes.contratoId;
            ICB_LogIntegracionService.publicarLogsOutboundPendientes();
            return out;

        } catch (ICB_FirmaDigitalServiceImpl.ICB_FirmaDigitalException e) {
            ICB_LogIntegracionService.publicarLogsOutboundPendientes();
            out.errorMessage = 'Firma Digital: ' + e.getMessage();
            try {
                crearContratoDigitalConError((Id) input.quoteId, e.getMessage());
            } catch (Exception ex) {
                out.errorMessage += ' No se pudo registrar el error en Contrato_Digital__c: ' + ex.getMessage();
            }
            return out;
        } catch (Exception e) {
            ICB_LogIntegracionService.publicarLogsOutboundPendientes();
            out.errorMessage = e.getMessage();
            try {
                crearContratoDigitalConError((Id) input.quoteId, e.getMessage());
            } catch (Exception ex) {
                out.errorMessage += ' No se pudo registrar el error en Contrato_Digital__c: ' + ex.getMessage();
            }
            return out;
        }
    }

    private static Quote obtenerQuote(Id quoteId) {
        List<Quote> listQ = [
            SELECT Id, Name, QuoteNumber, ContactId,
                   Contact.Name, Contact.Email, Contact.MobilePhone, Contact.RUT__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        return listQ.isEmpty() ? null : listQ[0];
    }

    // Por si el LWC manda data:application/pdf;base64,xxxx
    private static String quitarPrefijoDataUrl(String base64Input) {
        if (String.isBlank(base64Input)) {
            return base64Input;
        }
        Integer idx = base64Input.indexOf(',');
        if (idx > 0 && base64Input.startsWithIgnoreCase('data:')) {
            return base64Input.substring(idx + 1);
        }
        return base64Input.trim();
    }

    private static Contrato_Digital__c crearContratoDigital(
        Id quoteId, String contratoId, String documentoIdTuFirma, String urlFirma, String errorMsg,
        String firmanteNombre, String firmanteEmail, String firmanteTelefono, DateTime fechaEnvio, String pdfFirmadoUrl, String pdfOriginalUrl
    ) {
        Contrato_Digital__c c = new Contrato_Digital__c();
        c.Estado__c = errorMsg != null ? ESTADO_ERROR : ESTADO_ENVIADO;
        c.Contrato_ID__c = contratoId;
        if (String.isNotBlank(documentoIdTuFirma)) {
            c.Documento_ID_TuFirma_del__c = documentoIdTuFirma;
        }
        if (String.isNotBlank(urlFirma)) {
            c.URL_Firma__c = urlFirma;
        }
        if (String.isNotBlank(errorMsg)) {
            c.Error_Message__c = errorMsg;
        }
        if (String.isNotBlank(firmanteNombre)) {
            c.Firmante_Nombre__c = firmanteNombre;
        }
        if (String.isNotBlank(firmanteEmail)) {
            c.Firmante_Email__c = firmanteEmail;
        }
        if (String.isNotBlank(firmanteTelefono)) {
            c.Firmante_Telefono__c = firmanteTelefono;
        }
        if (fechaEnvio != null) {
            c.Fecha_Envio__c = fechaEnvio;
        }
        if (String.isNotBlank(pdfFirmadoUrl)) {
            c.PDF_Firmado_URL__c = pdfFirmadoUrl;
        }
        if (String.isNotBlank(pdfOriginalUrl)) {
            c.PDF_Original_URL__c = pdfOriginalUrl;
        }
        return c;
    }

    private static void crearContratoDigitalConError(Id quoteId, String errorMsg) {
        Contrato_Digital__c c = crearContratoDigital(quoteId, null, null, null, errorMsg, null, null, null, null, null, null);
        insert c;
    }
}