package usach.cl.tareasbackend.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import usach.cl.tareasbackend.dto.SectorDto;

import java.util.List;

/**
 * Acceso a datos de sectores (SQL explicito, sin ORM).
 */
@Repository
public class SectorRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public SectorRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Lista los sectores con sus coordenadas extraidas del punto PostGIS. */
    public List<SectorDto> listar() {
        String sql = """
                SELECT id_sector,
                       nombre,
                       ST_Y(ubicacion) AS latitud,
                       ST_X(ubicacion) AS longitud
                FROM sector
                ORDER BY nombre
                """;
        return jdbc.query(sql, (rs, i) -> new SectorDto(
                rs.getInt("id_sector"),
                rs.getString("nombre"),
                rs.getDouble("latitud"),
                rs.getDouble("longitud")));
    }

    /** Crea un sector georreferenciado y devuelve su id. */
    public int insertar(String nombre, double latitud, double longitud) {
        String sql = """
                INSERT INTO sector (nombre, ubicacion)
                VALUES (:nombre, ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326))
                RETURNING id_sector
                """;
        var params = new MapSqlParameterSource()
                .addValue("nombre", nombre)
                .addValue("latitud", latitud)
                .addValue("longitud", longitud);
        return jdbc.queryForObject(sql, params, Integer.class);
    }

    public boolean existeNombre(String nombre) {
        String sql = "SELECT COUNT(*) FROM sector WHERE LOWER(nombre) = LOWER(:nombre)";
        Integer n = jdbc.queryForObject(sql,
                new MapSqlParameterSource("nombre", nombre), Integer.class);
        return n != null && n > 0;
    }
}
