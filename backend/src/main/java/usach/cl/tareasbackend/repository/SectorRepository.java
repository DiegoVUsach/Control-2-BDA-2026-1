package usach.cl.tareasbackend.repository;

import usach.cl.tareasbackend.dto.SectorDto;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

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
}