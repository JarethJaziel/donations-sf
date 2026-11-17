/**
 * @description Revisa si un nombre público contiene una palabra o frase de la lista de palabras bloqueadas (US-19 AC2).
 *              La lista vive en Palabra_Bloqueada__c y la mantienen los moderadores sin cambios de código.
 *              La comparación ignora mayúsculas, acentos y signos, y busca palabras completas para no
 *              rechazar nombres que solo contienen las letras de una palabra bloqueada dentro de otra.
 *              Se consulta en modo sistema porque la llama el controlador público (el invitado no tiene permisos).
 */
public without sharing class FiltroPalabrasBloqueadas {

    private static final Integer MAX_PALABRAS = 2000;
    private static List<String> cache;

    /**
     * @description Indica si alguno de los textos contiene una palabra bloqueada.
     * @param textos Textos a revisar (nombre y nombre público); los vacíos se ignoran.
     * @return true si al menos uno contiene una palabra o frase bloqueada.
     */
    public static Boolean contieneBloqueada(List<String> textos) {
        List<String> bloqueadas = palabras();
        if (bloqueadas.isEmpty() || textos == null) {
            return false;
        }
        for (String texto : textos) {
            if (String.isBlank(texto)) {
                continue;
            }
            String enTexto = ' ' + normalizar(texto) + ' ';
            for (String palabra : bloqueadas) {
                if (enTexto.contains(' ' + palabra + ' ')) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @description Minúsculas, sin acentos, y cualquier signo o espacio repetido convertido en un solo espacio.
     * @param texto Texto original.
     * @return Texto normalizado.
     */
    @TestVisible
    private static String normalizar(String texto) {
        if (texto == null) {
            return '';
        }
        String s = texto.toLowerCase()
            .replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o')
            .replace('ú', 'u').replace('ü', 'u').replace('ñ', 'n');
        return s.replaceAll('[^a-z0-9]+', ' ').trim();
    }

    private static List<String> palabras() {
        if (cache == null) {
            cache = new List<String>();
            for (Palabra_Bloqueada__c p : [
                SELECT Name FROM Palabra_Bloqueada__c WITH SYSTEM_MODE ORDER BY Name LIMIT :MAX_PALABRAS
            ]) {
                String palabra = normalizar(p.Name);
                if (String.isNotBlank(palabra)) {
                    cache.add(palabra);
                }
            }
        }
        return cache;
    }
}
