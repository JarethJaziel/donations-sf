/**
 * @description Pruebas de la moderación del muro (US-19): lista de palabras bloqueadas (AC2),
 *              alcance del permiso de moderación (AC3) y bloqueo para usuarios sin ese permiso (AC4).
 *              Datos ficticios (M1).
 */
@IsTest
private class FiltroPalabrasBloqueadasTest {

    @TestSetup
    static void setup() {
        insert new List<Palabra_Bloqueada__c>{
            new Palabra_Bloqueada__c(Name = 'Estafa'),
            new Palabra_Bloqueada__c(Name = 'mal nombre')
        };
        Campana__c campana = DonacionTestFactory.campanaVigente('Campaña Moderación', 1000);
        insert campana;
        Donacion__c don = DonacionTestFactory.donacion(campana.Id, 'Con crédito', 300, 'moderacion@example.com');
        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Manual';
        don.Comprobante_Enviado__c = true;
        insert don;
    }

    // ---------- AC2: lista de palabras bloqueadas ----------

    @IsTest
    static void detectaPalabraSinImportarMayusculasNiAcentos() {
        Assert.isTrue(FiltroPalabrasBloqueadas.contieneBloqueada(new List<String>{ 'Grupo ESTAFÁ del Norte' }));
        Assert.isTrue(FiltroPalabrasBloqueadas.contieneBloqueada(new List<String>{ null, 'estafa' }));
    }

    @IsTest
    static void detectaFrasesCompletas() {
        Assert.isTrue(FiltroPalabrasBloqueadas.contieneBloqueada(new List<String>{ 'Un   mal-nombre aquí' }));
    }

    @IsTest
    static void noRechazaPalabrasQueSoloContienenLasLetras() {
        Assert.isFalse(FiltroPalabrasBloqueadas.contieneBloqueada(new List<String>{ 'Estafania Pérez', 'Familia Ficticia' }),
            'Solo se bloquean palabras completas');
        Assert.isFalse(FiltroPalabrasBloqueadas.contieneBloqueada(null));
    }

    @IsTest
    static void sinListaNoBloqueaNada() {
        delete [SELECT Id FROM Palabra_Bloqueada__c];
        Assert.isFalse(FiltroPalabrasBloqueadas.contieneBloqueada(new List<String>{ 'Estafa' }));
    }

    @IsTest
    static void normalizaTexto() {
        Assert.areEqual('nunez pena', FiltroPalabrasBloqueadas.normalizar('  Núñez & Peña! '));
        Assert.areEqual('', FiltroPalabrasBloqueadas.normalizar(null));
    }

    // ---------- AC3 y AC4: permisos ----------

    private static User usuario(String alias, List<String> permisos) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile perfil = [
                SELECT Id FROM Profile
                WHERE Name IN ('Standard User', 'Usuario estándar')
                LIMIT 1
            ];
            u = new User(
                Alias = alias,
                Email = alias + '@example.com',
                Username = alias + '.' + System.currentTimeMillis() + '@md2026.example.com',
                LastName = 'Usuario Ficticio',
                ProfileId = perfil.Id,
                TimeZoneSidKey = 'America/Mexico_City',
                LocaleSidKey = 'es_MX',
                LanguageLocaleKey = 'es',
                EmailEncodingKey = 'UTF-8'
            );
            insert u;
            List<PermissionSetAssignment> asignaciones = new List<PermissionSetAssignment>();
            for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :permisos]) {
                asignaciones.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
            }
            insert asignaciones;
        }
        return u;
    }

    @IsTest
    static void moderadorSoloCambiaNombrePublicoYVisibilidad() {
        User moderador = usuario('modmd26', new List<String>{ 'Moderacion_Reconocimiento' });
        Donacion__c don = [SELECT Id FROM Donacion__c LIMIT 1];

        System.runAs(moderador) {
            update as user new Donacion__c(Id = don.Id, Nombre_Publico__c = 'Nombre Corregido', Visible_En_Reconocimiento__c = false);

            String mensaje = 'sin error';
            try {
                update new Donacion__c(Id = don.Id, Monto__c = 500);
            } catch (DmlException ex) {
                mensaje = ex.getMessage();
            }
            Assert.isTrue(mensaje.contains('moderación'), 'US-19 AC3: el moderador no puede cambiar el monto. Resultado: ' + mensaje);

            insert as user new Palabra_Bloqueada__c(Name = 'Otra Palabra');
        }
        Donacion__c despues = [SELECT Nombre_Publico__c, Visible_En_Reconocimiento__c, Monto__c FROM Donacion__c WHERE Id = :don.Id];
        Assert.areEqual('Nombre Corregido', despues.Nombre_Publico__c);
        Assert.isFalse(despues.Visible_En_Reconocimiento__c, 'US-19 AC1: el moderador puede ocultar la entrada');
        Assert.areEqual(300, despues.Monto__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Palabra_Bloqueada__c WHERE Name = 'Otra Palabra'], 'El moderador mantiene la lista');
    }

    @IsTest
    static void sinPermisoDeModeracionNoPuedeOcultarNiEditarLaLista() {
        User otro = usuario('sinmd26', new List<String>());
        Donacion__c don = [SELECT Id FROM Donacion__c LIMIT 1];
        Boolean ocultaBloqueado = false;
        Boolean listaBloqueada = false;

        System.runAs(otro) {
            try {
                update as user new Donacion__c(Id = don.Id, Visible_En_Reconocimiento__c = false);
            } catch (Exception ex) {
                ocultaBloqueado = true;
            }
            try {
                insert as user new Palabra_Bloqueada__c(Name = 'No Permitida');
            } catch (Exception ex) {
                listaBloqueada = true;
            }
        }
        Assert.isTrue(ocultaBloqueado, 'US-19 AC4: sin el permiso no puede ocultar una entrada');
        Assert.isTrue(listaBloqueada, 'US-19 AC4: sin el permiso no puede editar la lista');
        Assert.isTrue([SELECT Visible_En_Reconocimiento__c FROM Donacion__c WHERE Id = :don.Id].Visible_En_Reconocimiento__c);
    }
}
