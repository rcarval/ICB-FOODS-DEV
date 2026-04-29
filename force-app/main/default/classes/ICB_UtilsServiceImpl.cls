/**********************************************************************************
Desarrollado por: SEIDOR
Autor: Rodrigo Carvallo (RCG)
Proyecto: Maestra de Precios - Perfomance
Descripción: Clase de utilitarios para Maestra de Precios
Test: ICB_UtilsService_Test

---------------------------------------------------------------------------------
No. Fecha                Autor                     Descripción
------ ---------- ---------------------------------------------------------------
1.0 11-09-2025            RCG                Creación de la clase.
**********************************************************************************/
public class ICB_UtilsServiceImpl{

    /**
    * Método que retorna el nombre en formato texto del mes en curso
    * @author Rodrigo Carvallo
    * @return String
    **/
    public static String generarEncabezado(){
        Date today = System.today();
        List<String> meses = new List<String>{
            'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
                };
        String mesTexto = meses[today.month() - 1];
        String anio = String.valueOf(today.year());
        return mesTexto.toUpperCase() + ' ' + anio;
    }

    /**
    * Método para formatear fechas de componente
    * @author Rodrigo Carvallo
    * @param List<Detalle_Factura__c> comprasMaestradePrecios
    **/
    public static void formatearFechas(List<Detalle_Factura__c> comprasMaestradePrecios){
        system.debug('formatear fecha ');
        for (Detalle_Factura__c detalle : comprasMaestradePrecios) {
            // Descuento_Cliente__r nunca tuvo valores, usar Product__r.Fecha_maxima_de_descuento__c
            Date fecha = detalle.Product__r.Fecha_maxima_de_descuento__c;
            system.debug('fecha ' + detalle.Product__r.Fecha_maxima_de_descuento__c);
            // Fecha_Vencimiento_Formateada__c no existe en Detalle_Factura__c, campo eliminado
            // La fecha de vencimiento está disponible en detalle.Product__r.Fecha_maxima_de_descuento__c si se necesita
        }
    }

}