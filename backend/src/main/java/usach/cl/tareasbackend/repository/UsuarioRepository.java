//SQL explícito parametrizado (prepared statements = sin inyección);
// el punto PostGIS entra con ST_MakePoint y sale con ST_X/ST_Y.

package usach.cl.tareasbackend.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Map;
import java.util.Optional;

/**
 * Acceso a datos de usuarios con SQL explicito (sin ORM).
 * Todas las consultas usan parametros nombrados, que se traducen a
 * prepared statements: proteccion contra inyeccion SQL.
 */
@Repository
public class UsuarioRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public UsuarioRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Registra un usuario guardando su ubicacion como punto PostGIS. */
    public int insertar(String nombreUsuario, String hashContrasena,
                        String direccion, double latitud, double longitud) {
        String sql = """
                INSERT INTO usuario (nombre_usuario, contrasena, direccion, ubicacion)
                VALUES (:nombre, :contrasena, :direccion,
                        ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326))
                RETURNING id_usuario
                """;
        var params = new MapSqlParameterSource()
                .addValue("nombre", nombreUsuario)
                .addValue("contrasena", hashContrasena)
                .addValue("direccion", direccion)
                .addValue("latitud", latitud)
                .addValue("longitud", longitud);
        return jdbc.queryForObject(sql, params, Integer.class);
    }

    /** Busca un usuario por nombre; retorna id y hash de contrasena. */
    public Optional<Map<String, Object>> buscarPorNombre(String nombreUsuario) {
        String sql = """
                SELECT id_usuario, nombre_usuario, contrasena
                FROM usuario
                WHERE nombre_usuario = :nombre
                """;
        var params = new MapSqlParameterSource("nombre", nombreUsuario);
        return jdbc.queryForList(sql, params).stream().findFirst();
    }

    /** Perfil del usuario con sus coordenadas extraidas del punto PostGIS. */
    public Optional<Map<String, Object>> datosPerfil(int idUsuario) {
        String sql = """
                SELECT id_usuario, nombre_usuario, direccion,
                       ST_Y(ubicacion) AS latitud,
                       ST_X(ubicacion) AS longitud
                FROM usuario
                WHERE id_usuario = :id
                """;
        var params = new MapSqlParameterSource("id", idUsuario);
        return jdbc.queryForList(sql, params).stream().findFirst();
    }

    public boolean existeNombre(String nombreUsuario) {
        String sql = "SELECT COUNT(*) FROM usuario WHERE nombre_usuario = :nombre";
        Integer n = jdbc.queryForObject(sql,
                new MapSqlParameterSource("nombre", nombreUsuario), Integer.class);
        return n != null && n > 0;
    }
}