trigger DocumentoFirmadoTrigger on DocumentoFirmado__e (after insert) {
    ICB_DocumentoFirmadoTriggerHandler.onAfterInsert(Trigger.new);
}