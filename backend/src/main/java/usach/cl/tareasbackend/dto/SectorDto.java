package usach.cl.tareasbackend.dto;

/**
 * Sector de trabajo con su punto georreferenciado.
 */
public record SectorDto(int idSector, String nombre, double latitud, double longitud) {
}