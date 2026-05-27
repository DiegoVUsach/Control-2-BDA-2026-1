package com.example.demo.repositories;

import com.example.demo.entities.Tarea;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface TareaRepository extends JpaRepository<Tarea, Long> {

    
    // El listado general y las búsquedas por palabra clave ahora exigen filtrar por el dueño
    @Query(value = "SELECT * FROM TAREAS WHERE id_usuario = :idUsuario AND completada = :completada " +
                   "AND (LOWER(titulo) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
                   "OR LOWER(descripcion) LIKE LOWER(CONCAT('%', :keyword, '%')))", 
           nativeQuery = true)
    List<Tarea> buscarPorUsuarioEstadoYPalabraClave(@Param("idUsuario") Long idUsuario,
                                                    @Param("completada") boolean completada, 
                                                    @Param("keyword") String keyword);

    // Compatibility methods expected by service layer (non-owner and aggregated variants)
    @Query(value = "SELECT * FROM TAREAS WHERE completada = :completada " +
                   "AND (LOWER(titulo) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
                   "OR LOWER(descripcion) LIKE LOWER(CONCAT('%', :keyword, '%')))", 
           nativeQuery = true)
    List<Tarea> buscarPorEstadoYPalabraClave(@Param("completada") boolean completada, 
                                             @Param("keyword") String keyword);


    // =====================================================================
    // CONSULTAS ANALÍTICAS ESPACIALES CORREGIDAS (Aisladas por Usuario)
    // =====================================================================

    /**
     * PREGUNTA 1: ¿Cuántas tareas ha realizado el usuario por sector?
     * EXPLICACIÓN: Añadimos la cláusula "WHERE t.id_usuario = :idUsuario" para cumplir 
     * estrictamente con lo indicado por el ayudante.
     */
    @Query(value = "SELECT u.username, s.nombre_sector, COUNT(t.id_tarea) as cantidad " +
                   "FROM TAREAS t " +
                   "JOIN USUARIOS u ON t.id_usuario = u.id_usuario " +
                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                   "WHERE t.completada = true AND t.id_usuario = :idUsuario " +
                   "GROUP BY u.username, s.nombre_sector", 
           nativeQuery = true)
    List<Object[]> contarTareasCompletadasPropiasPorSector(@Param("idUsuario") Long idUsuario);

        @Query(value = "SELECT u.username, s.nombre_sector, COUNT(t.id_tarea) as cantidad " +
                                   "FROM TAREAS t " +
                                   "JOIN USUARIOS u ON t.id_usuario = u.id_usuario " +
                                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                                   "WHERE t.completada = true " +
                                   "GROUP BY u.username, s.nombre_sector", 
                   nativeQuery = true)
        List<Object[]> contarTareasCompletadasPorUsuarioYSector();

    /**
     * PREGUNTA 2: ¿Cuál es la tarea más cercana al usuario que esté pendiente?
     * EXPLICACIÓN: Filtra por el id del usuario actual ("t.id_usuario = :idUsuario") 
     * y calcula la distancia con ST_Distance hacia el sector asignado.
     */
    @Query(value = "SELECT t.* FROM TAREAS t " +
                   "JOIN USUARIOS u ON u.id_usuario = t.id_usuario " +
                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                   "WHERE t.completada = false AND t.id_usuario = :idUsuario " +
                   "ORDER BY ST_Distance(u.ubicacion, s.ubicacion_spatial) ASC " +
                   "LIMIT 1", 
           nativeQuery = true)
    Tarea encontrarTareaMasCercanaPendientePropia(@Param("idUsuario") Long idUsuario);

        @Query(value = "SELECT t.* FROM TAREAS t " +
                                   "JOIN USUARIOS u ON u.id_usuario = t.id_usuario " +
                                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                                   "WHERE t.completada = false AND t.id_usuario = :idUsuario " +
                                   "ORDER BY ST_Distance(u.ubicacion, s.ubicacion_spatial) ASC " +
                                   "LIMIT 1", 
                   nativeQuery = true)
        Tarea encontrarTareaMasCercanaPendiente(@Param("idUsuario") Long idUsuario);

    /**
     * PREGUNTA 3: ¿Cuál es el sector con más tareas completadas dentro de un radio de 5 km (o 2 km) desde el usuario?
     * EXPLICACIÓN: Buscamos únicamente entre las tareas finalizadas del usuario actual en zonas geográficas 
     * delimitadas mediante la función espacial ST_DWithin (casteando a geography para obtener metros reales).
     */
    @Query(value = "SELECT s.id_sector, s.nombre_sector, COUNT(t.id_tarea) as completadas " +
                   "FROM TAREAS t " +
                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                   "JOIN USUARIOS u ON u.id_usuario = t.id_usuario " +
                   "WHERE t.completada = true AND t.id_usuario = :idUsuario " +
                   "AND ST_DWithin(u.ubicacion::geography, s.ubicacion_spatial::geography, :radioMetros) " +
                   "GROUP BY s.id_sector, s.nombre_sector " +
                   "ORDER BY completadas DESC " +
                   "LIMIT 1", 
           nativeQuery = true)
    List<Object[]> encontrarSectorMasActivoPropioEnRadio(@Param("idUsuario") Long idUsuario, 
                                                         @Param("radioMetros") double radioMetros);

        @Query(value = "SELECT s.id_sector, s.nombre_sector, COUNT(t.id_tarea) as completadas " +
                                   "FROM TAREAS t " +
                                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                                   "JOIN USUARIOS u ON u.id_usuario = t.id_usuario " +
                                   "WHERE t.completada = true " +
                                   "AND ST_DWithin(u.ubicacion::geography, s.ubicacion_spatial::geography, :radioMetros) " +
                                   "GROUP BY s.id_sector, s.nombre_sector " +
                                   "ORDER BY completadas DESC " +
                                   "LIMIT 1", 
                   nativeQuery = true)
        List<Object[]> encontrarSectorMasActivoEnRadio(@Param("idUsuario") Long idUsuario, 
                                                                                                   @Param("radioMetros") double radioMetros);

    /**
     * PREGUNTA 4: ¿Cuál es el promedio de distancia entre las tareas completadas y el punto registrado del usuario?
     * EXPLICACIÓN: Se mantiene idéntica pero conceptualmente ahora está alineada; calcula la media aritmética 
     * de las distancias espaciales usando funciones nativas de PostGIS.
     */
    @Query(value = "SELECT COALESCE(AVG(ST_Distance(u.ubicacion::geography, s.ubicacion_spatial::geography)), 0) " +
                   "FROM TAREAS t " +
                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                   "JOIN USUARIOS u ON t.id_usuario = u.id_usuario " +
                   "WHERE t.completada = true AND u.id_usuario = :idUsuario", 
           nativeQuery = true)
    Double calcularPromedioDistanciaTareasCompletadasPropias(@Param("idUsuario") Long idUsuario);

        @Query(value = "SELECT COALESCE(AVG(ST_Distance(u.ubicacion::geography, s.ubicacion_spatial::geography)), 0) " +
                                   "FROM TAREAS t " +
                                   "JOIN SECTORES s ON t.id_sector = s.id_sector " +
                                   "JOIN USUARIOS u ON t.id_usuario = u.id_usuario " +
                                   "WHERE t.completada = true AND u.id_usuario = :idUsuario", 
                   nativeQuery = true)
        Double calcularPromedioDistanciaTareasCompletadas(@Param("idUsuario") Long idUsuario);
}