/**
 * @description Utilidad para normalizar y validar RFC mexicanos contra el patrón del SAT,
 *              incluyendo que la fecha AAMMDD exista en el calendario (US-05 AC2/AC5).
 *              No consulta la base de datos del SAT. La reutiliza el portal público (Integrante 2).
 */
public with sharing class RfcValidator {

    private static final Pattern PATRON_RFC = Pattern.compile(
        '^[A-Z&Ñ]{3,4}([0-9]{2})([0-9]{2})([0-9]{2})[A-Z0-9]{3}$'
    );

    /**
     * @description Quita espacios al inicio y al final y convierte a mayúsculas.
     * @param rfc Valor capturado por el usuario.
     * @return RFC normalizado, o null si el valor es nulo.
     */
    public static String normalizar(String rfc) {
        return rfc == null ? null : rfc.trim().toUpperCase();
    }

    /**
     * @description Indica si el RFC cumple la estructura del SAT (letras, 6 dígitos y homoclave),
     *              sin revisar si la fecha existe.
     * @param rfc Valor a revisar (se normaliza internamente).
     * @return true si la estructura coincide.
     */
    public static Boolean tieneFormato(String rfc) {
        String valor = normalizar(rfc);
        return String.isNotBlank(valor) && PATRON_RFC.matcher(valor).matches();
    }

    /**
     * @description Valida estructura y fecha. Acepta la fecha si existe en el siglo XX o en el XXI
     *              (por ejemplo, 29 de febrero de 2000 o de 1996).
     * @param rfc Valor a revisar (se normaliza internamente).
     * @return true si el RFC es válido.
     */
    public static Boolean esValido(String rfc) {
        String valor = normalizar(rfc);
        if (String.isBlank(valor)) {
            return false;
        }
        Matcher coincidencia = PATRON_RFC.matcher(valor);
        if (!coincidencia.matches()) {
            return false;
        }
        Integer anio = Integer.valueOf(coincidencia.group(1));
        Integer mes = Integer.valueOf(coincidencia.group(2));
        Integer dia = Integer.valueOf(coincidencia.group(3));
        return fechaExiste(1900 + anio, mes, dia) || fechaExiste(2000 + anio, mes, dia);
    }

    private static Boolean fechaExiste(Integer anio, Integer mes, Integer dia) {
        if (mes < 1 || mes > 12 || dia < 1) {
            return false;
        }
        return dia <= Date.daysInMonth(anio, mes);
    }
}
