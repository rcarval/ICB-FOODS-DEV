import { LightningElement, track } from 'lwc';
import getDashboardOptions from '@salesforce/apex/ICBFS_QuicksightEmbedController.getDashboardOptions';
import getEmbedUrlForDashboard from '@salesforce/apex/ICBFS_QuicksightEmbedController.getEmbedUrlForDashboard';

export default class EmbedDashboard extends LightningElement {
    @track options = [];
    @track selectedValue;
    @track embedUrl;
    @track loading = false;
    @track error;

    connectedCallback() {
        this.init();
    }

    async init() {
        try {
            this.loading = true;
            this.options = await getDashboardOptions();
            if (this.options.length > 0) {
                this.selectedValue = this.options[0].value;
                await this.loadEmbedUrl();
            }
        } catch (e) {
            this.error = 'No fue posible cargar los dashboards';
            console.error(e);
        } finally {
            this.loading = false;
        }
    }

    async loadEmbedUrl() {
    if (!this.selectedValue) return;

    const MIN_LOADING_TIME = 5000; // tiempo mínimo visible del mensaje (ms)
    const startTime = Date.now();

    try {
        this.loading = true;
        this.embedUrl = await getEmbedUrlForDashboard({
            dashboardId: this.selectedValue
        });
    } catch (e) {
        this.error = e.body?.message || 'Error al generar dashboard';
        console.error(e);
    } finally {
        const elapsed = Date.now() - startTime;
        const remainingTime = MIN_LOADING_TIME - elapsed;

        if (remainingTime > 0) {
            setTimeout(() => {
                this.loading = false;
            }, remainingTime);
        } else {
            this.loading = false;
        }
    }
}

    // async loadEmbedUrl() {
    //     if (!this.selectedValue) return;
    //     try {
    //         this.loading = true;
    //         this.embedUrl = await getEmbedUrlForDashboard({
    //             dashboardId: this.selectedValue
    //         });
    //     } catch (e) {
    //         this.error = e.body?.message || 'Error al generar dashboard';
    //         console.error(e);
    //     } finally {
    //         this.loading = false;
    //     }
    // }

    async handleGoToUrlWithRefresh() {
    if (!this.selectedValue) return;

    try {
        this.loading = true;

        // Se vuelve a invocar Apex para generar una URL fresca
        const newEmbedUrl = await getEmbedUrlForDashboard({
            dashboardId: this.selectedValue
        });

        if (newEmbedUrl) {
            // Se abre la nueva URL en una nueva pestaña
            window.open(newEmbedUrl, '_blank');
        }
    } catch (e) {
        this.error = e.body?.message || 'Error al abrir dashboard en QuickSight';
        console.error(e);
    } finally {
        this.loading = false;
    }
}

    handleSelectionChange(event) {
        this.selectedValue = event.detail.value;
        this.loadEmbedUrl();
    }

    handleReload() {
        this.loadEmbedUrl();
    }

    get hasError() {
        return this.error && this.error.length > 0;
    }
    handleGoToUrl() {
        if (this.embedUrl) {
            window.open(this.embedUrl, '_blank');
        }
    }
}