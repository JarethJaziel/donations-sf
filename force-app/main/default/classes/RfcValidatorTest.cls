/**
 * @description Pruebas de RfcValidator (US-05 AC2/AC5). RFCs ficticios o genéricos del SAT.
 */
@IsTest
private class RfcValidatorTest {

    @IsTest
    static void aceptaRfcValidosDePersonaMoralYFisica() {
        System.assert(RfcValidator.esValido('EKU9003173C9'), 'RFC de persona moral (12) válido');
        System.assert(RfcValidator.esValido('GODE561231GR8'), 'RFC de persona física (13) válido');
        System.assert(RfcValidator.esValido('XAXX010101000'), 'RFC genérico válido');
    }

    @IsTest
    static void normalizaEspaciosYMinusculas() {
        System.assertEquals('GODE561231GR8', RfcValidator.normalizar('  gode561231gr8 '));
        System.assert(RfcValidator.esValido(' gode561231gr8 '), 'Debe validar después de normalizar');
        System.assertEquals(null, RfcValidator.normalizar(null));
    }

    @IsTest
    static void rechazaFechasInexistentes() {
        System.assert(RfcValidator.tieneFormato('GODE560230GR8'), 'La estructura de 30 de febrero es correcta');
        System.assertEquals(false, RfcValidator.esValido('GODE560230GR8'), '30 de febrero no existe');
        System.assertEquals(false, RfcValidator.esValido('GODE561331GR8'), 'El mes 13 no existe');
        System.assertEquals(false, RfcValidator.esValido('GODE560431GR8'), '31 de abril no existe');
        System.assertEquals(false, RfcValidator.esValido('GODE560100GR8'), 'El día 00 no existe');
    }

    @IsTest
    static void aceptaVeintinueveDeFebreroEnAnioBisiesto() {
        System.assert(RfcValidator.esValido('GODE000229GR8'), '29/02/2000 existe');
        System.assert(RfcValidator.esValido('GODE960229GR8'), '29/02/1996 existe');
        System.assertEquals(false, RfcValidator.esValido('GODE970229GR8'), '29/02/1997 no existe');
    }

    @IsTest
    static void rechazaEstructurasInvalidas() {
        System.assertEquals(false, RfcValidator.esValido(null));
        System.assertEquals(false, RfcValidator.esValido(''));
        System.assertEquals(false, RfcValidator.esValido('ABC123'), 'Longitud inválida');
        System.assertEquals(false, RfcValidator.esValido('GODE5612$1GR8'), 'Símbolos no permitidos');
        System.assertEquals(false, RfcValidator.tieneFormato('12345678901234'), 'Sin letras iniciales');
    }
}
