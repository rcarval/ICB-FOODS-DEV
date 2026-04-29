import { LightningElement, api } from 'lwc';

const LOG = '[MotivoComboboxCell]';

export default class MotivoComboboxCell extends LightningElement {
    @api value;
    @api options = [];
    @api context;
    @api fieldName = 'motivoFuga';

    _justCommitted = false;

    /**
     * Evita que el mousedown llegue al datatable: así el panel no se cierra al hacer
     * clic en "Seleccionar motivo" y el desplegable puede abrirse.
     */
    handleMouseDownOnCell(event) {
        event.stopPropagation();
        event.stopImmediatePropagation();
    }

    /**
     * Al perder foco: si en unos ms el usuario eligió un valor (handleChange), no hacemos nada.
     * Si no eligió (clic fuera o tab), cerramos con cancel. Retraso para no cerrar antes del change al elegir de la lista.
     */
    handleFocusOut() {
        if (this._justCommitted) {
            this._justCommitted = false;
            return;
        }
        const rowKey = this.context;
        const colKey = this.fieldName;
        const delayMs = 280;
        setTimeout(() => {
            if (this._justCommitted) {
                this._justCommitted = false;
                return;
            }
            try {
                this.dispatchEvent(
                    new CustomEvent('ieditfinished', {
                        bubbles: true,
                        composed: true,
                        cancelable: false,
                        detail: { reason: 'cancel', rowKeyValue: rowKey, colKeyValue: colKey }
                    })
                );
            } catch (e) {
                console.error(LOG, 'handleFocusOut', e?.message, e);
            }
        }, delayMs);
    }

    handleChange(event) {
        console.log(LOG, 'handleChange ENTRY', { type: event?.type, detail: event?.detail });
        event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
        let newValue;
        try {
            newValue = event.detail?.value;
            console.log(LOG, 'handleChange newValue', newValue);
        } catch (e1) {
            console.error(LOG, 'handleChange reading detail', e1?.message, e1?.stack, e1);
            return;
        }
        const draft = {};
        draft[this.fieldName] = newValue;
        if (this.context != null) {
            draft['id'] = this.context;
        }
        const draftValues = [draft];
        const rowKey = this.context;
        const colKey = this.fieldName;
        this._justCommitted = true;
        console.log(LOG, 'handleChange draftValues', JSON.stringify(draftValues));
        setTimeout(() => {
            console.log(LOG, 'setTimeout ENTRY');
            try {
                console.log(LOG, 'dispatch cellchange');
                this.dispatchEvent(
                    new CustomEvent('cellchange', {
                        bubbles: true,
                        composed: true,
                        cancelable: true,
                        detail: { draftValues }
                    })
                );
                console.log(LOG, 'dispatch cellchange OK');
                console.log(LOG, 'dispatch ieditfinished');
                this.dispatchEvent(
                    new CustomEvent('ieditfinished', {
                        bubbles: true,
                        composed: true,
                        cancelable: false,
                        detail: {
                            reason: 'value-selected',
                            rowKeyValue: rowKey,
                            colKeyValue: colKey
                        }
                    })
                );
                console.log(LOG, 'dispatch ieditfinished OK');
            } catch (e) {
                console.error(LOG, 'setTimeout catch', e?.message, e?.stack, String(e), e);
            }
        }, 0);
        console.log(LOG, 'handleChange EXIT');
    }
}