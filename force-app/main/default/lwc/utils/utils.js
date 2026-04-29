function calculateMargen(product) {
    let margen = 0;
    if (product.costo == null || product.costo == undefined || product.costo == 0) {
        margen = 'SIN COSTO';
    } else if (product.rappel != null) {
        const rappelAplicado = Number(product.precioClienteNeto) * (product.rappel / 100);
        const precioConRappel = Number(product.precioClienteNeto) + rappelAplicado;
        margen = ((precioConRappel - product.costo) / precioConRappel) * 100;
        margen = margen.toFixed(2).toString();
    } else {
        margen = ((product.precioClienteNeto - product.costo) / product.precioClienteNeto) * 100;
        margen = margen.toFixed(2).toString();
    }
    return margen;
}
    
function calculateKilo(product) {
    let margenKilo = 0;
    if (product.peso != null) {
        margenKilo = ((product.precioClienteNeto - product.costo) / product.peso);
    } 
    return margenKilo.toFixed(2);
}

export { calculateMargen, calculateKilo };