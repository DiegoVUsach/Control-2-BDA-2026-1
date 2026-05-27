package com.example.demo.repositories;

import com.example.demo.entities.Usuario;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.util.List;

// @Repository le dice a Spring que esta clase maneja acceso a datos.
// Spring la detecta automaticamente y la hace disponible para inyeccion.
@Repository
public class UsuarioRepository {

    // JdbcTemplate es la herramienta de Spring para ejecutar SQL puro.
    // NO es un ORM: nosotros escribimos el SQL a mano.
    // @Autowired le dice a Spring "inyectame una instancia de JdbcTemplate".
    @Autowired
    private JdbcTemplate jdbcTemplate;

    // RowMapper: le enseña a JdbcTemplate como convertir una fila SQL
    // en un objeto Java. Por cada fila del ResultSet, crea un Usuario
    // y mapea cada columna al campo correspondiente.
    private final RowMapper<Usuario> rowMapper = (rs, rowNum) -> {
        Usuario u = new Usuario();
        u.setIdUsuario(rs.getLong("id_usuario"));
        u.setUsername(rs.getString("username"));
        u.setPassword(rs.getString("password"));
        // ubicacion is omitted here; mapping geospatial types via JdbcTemplate
        // is out of scope for the login flow. Leave ubicacion null.
        return u;
    };

    // SELECT * FROM usuario → devuelve lista de todos los usuarios
    public List<Usuario> findAll() {
        return jdbcTemplate.query("SELECT * FROM usuario", rowMapper);
    }

    // Buscar por ID. Retorna null si no existe.
    public Usuario findById(Integer id) {
        List<Usuario> list = jdbcTemplate.query(
                "SELECT * FROM usuario WHERE id_usuario = ?", rowMapper, id);
        return list.isEmpty() ? null : list.get(0);
    }

    // Buscar por nombre de usuario (para el login).
    public Usuario findByUsername(String username) {
        List<Usuario> list = jdbcTemplate.query(
                "SELECT * FROM usuario WHERE username = ?", rowMapper, username);
        return list.isEmpty() ? null : list.get(0);
    }

    // INSERT: el ? se reemplaza por los parametros en orden.
    // Esto previene SQL injection.
    public int save(Usuario entity) {
        String sql = "INSERT INTO usuario (username, password) VALUES (?, ?)";
        return jdbcTemplate.update(sql,
                entity.getUsername(),
                entity.getPassword());
    }

    // Inserta un usuario con ubicación geográfica (PostGIS) utilizando números
    // directos
    public int saveWithLocation(String username, String password, double lon, double lat) {
        // Al usar ST_MakePoint(?, ?), evitamos usar String.format y los errores de
        // comas/puntos decimales
        String sql = "INSERT INTO usuario (username, password, ubicacion) VALUES (?, ?, ST_SetSRID(ST_MakePoint(?, ?), 4326))";

        // Pasamos los parámetros en orden estricto: username, password, longitud,
        // latitud
        return jdbcTemplate.update(sql, username, password, lon, lat);
    }

    // UPDATE: modifica un usuario existente por su ID.
    public int update(Usuario entity) {
        String sql = "UPDATE usuario SET username = ?, password = ? WHERE id_usuario = ?";
        return jdbcTemplate.update(sql,
                entity.getUsername(),
                entity.getPassword(),
                entity.getIdUsuario());
    }

    // DELETE: elimina un usuario por su ID.
    public int deleteById(Integer id) {
        return jdbcTemplate.update("DELETE FROM usuario WHERE id_usuario = ?", id);
    }
}