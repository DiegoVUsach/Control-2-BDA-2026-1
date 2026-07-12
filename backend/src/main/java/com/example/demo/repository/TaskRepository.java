package com.example.demo.repository;

import com.example.demo.entity.TaskEntity;
import org.locationtech.jts.geom.Point;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TaskRepository extends JpaRepository<TaskEntity, Long> {

    // Filtros y Búsqueda: estado y palabras clave en título o descripción
    @Query("SELECT t FROM TaskEntity t WHERE t.completed = :completed AND (LOWER(t.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR LOWER(t.description) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<TaskEntity> searchTasksByStatusAndKeyword(@Param("completed") boolean completed, @Param("keyword") String keyword);

    // 1. ¿Cuántas tareas ha hecho el usuario por sector?
    @Query("SELECT t.sector.name, COUNT(t) FROM TaskEntity t WHERE t.user.id = :userId AND t.completed = true GROUP BY t.sector.name")
    List<Object[]> countCompletedTasksByUserIdPerSector(@Param("userId") Long userId);

    // 2. ¿Cuál es la tarea más cercana al usuario (que esté pendiente)?
    @Query(value = "SELECT t.* FROM tasks t WHERE t.completed = false ORDER BY ST_Distance(t.location\\:\\:geography, :userLocation\\:\\:geography) ASC LIMIT 1", nativeQuery = true)
    TaskEntity findClosestPendingTaskToUser(@Param("userLocation") Point userLocation);

    // 3. ¿Cuál es el sector con más tareas completadas en un radio de 2 kilómetros del usuario?
    // 7. ¿Cuál es el sector con más tareas completadas dentro de un radio de 5 km desde la ubicación del usuario?
    @Query(value = "SELECT s.name FROM sectors s JOIN tasks t ON s.id = t.sector_id " +
            "WHERE t.completed = true AND ST_DWithin(t.location\\:\\:geography, :userLocation\\:\\:geography, :radiusInMeters) " +
            "GROUP BY s.id ORDER BY COUNT(t.id) DESC LIMIT 1", nativeQuery = true)
    String findTopSectorWithCompletedTasksWithinRadius(@Param("userLocation") Point userLocation, @Param("radiusInMeters") double radiusInMeters);

    // 4 & 8. ¿Cuál es el promedio de distancia de las tareas completadas respecto a la ubicación del usuario?
    @Query(value = "SELECT AVG(ST_Distance(t.location\\:\\:geography, :userLocation\\:\\:geography)) " +
            "FROM tasks t WHERE t.user_id = :userId AND t.completed = true", nativeQuery = true)
    Double getAverageDistanceFromCompletedTasksToUser(@Param("userId") Long userId, @Param("userLocation") Point userLocation);

    // 5. ¿En qué sectores geográficos se concentran la mayoría de las tareas pendientes? (utilizando agrupación espacial).
    @Query(value = "SELECT cluster_id, COUNT(id) as num_tasks FROM " +
            "(SELECT id, ST_ClusterDBSCAN(location, 0.01, 2) OVER () AS cluster_id FROM tasks WHERE completed = false) sq " +
            "WHERE cluster_id IS NOT NULL GROUP BY cluster_id ORDER BY num_tasks DESC", nativeQuery = true)
    List<Object[]> findPendingTasksSpatialClusters();

    // 6. ¿Cuántas tareas ha realizado cada usuario por sector?
    @Query("SELECT t.user.username, t.sector.name, COUNT(t) FROM TaskEntity t WHERE t.completed = true GROUP BY t.user.username, t.sector.name")
    List<Object[]> countCompletedTasksPerUserAndSector();
}
