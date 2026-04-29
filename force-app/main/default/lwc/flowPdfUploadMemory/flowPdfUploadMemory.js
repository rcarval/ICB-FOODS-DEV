import { LightningElement, api } from 'lwc';

// PDF en memoria para el flujo (base64 + nombre). No se persiste en ContentVersion.
export default class FlowPdfUploadMemory extends LightningElement {
    @api pdfBase64 = '';
    @api pdfFileName = '';

    _fileName = '';

    get fileName() {
        return this._fileName;
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) {
            this.pdfBase64 = '';
            this.pdfFileName = '';
            this._fileName = '';
            return;
        }
        const file = files[0];
        if (!file.type || !file.type.toLowerCase().includes('pdf')) {
            this.pdfBase64 = '';
            this.pdfFileName = '';
            this._fileName = '';
            return;
        }
        this._fileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            const dataUrl = reader.result;
            this.pdfBase64 = dataUrl || '';
            this.pdfFileName = file.name || 'documento.pdf';
        };
        reader.readAsDataURL(file);
    }
}