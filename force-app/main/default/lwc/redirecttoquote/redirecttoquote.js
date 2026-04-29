import { LightningElement, api } from 'lwc';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';

export default class RedirectToQuote extends LightningElement {
    @api recordIdToRedirect;
    @api isLoading = false;

    connectedCallback() {
        this.isLoading = true;
        this.redirectToRecord();
    }

    redirectToRecord() {
        // Construye la URL de redirección
        const url = `/lightning/r/Quote/${this.recordIdToRedirect}/view`;
        // Realiza la redirección
        window.location.href = url;
        // Finaliza el Flow después de la redirección
        setTimeout(() => {
            this.finishFlow();
        }, 1000);  // Ajusta el tiempo según sea necesario
    }

    finishFlow() {
        // Crea y despacha el evento FlowNavigationFinishEvent para finalizar el Flow
        const finishEvent = new FlowNavigationFinishEvent();
        this.dispatchEvent(finishEvent);
    }
}