/**
 * Utilidades de geolocalizacion compartidas por registro y creacion de sector.
 * Flujo: se intenta el GPS del navegador; si el usuario lo permite, el punto
 * queda pre-marcado y el mapa centrado ahi para AJUSTAR con un clic; si lo
 * rechaza (o no hay soporte / contexto seguro), el mapa queda centrado por
 * defecto en Santiago (Region Metropolitana) y el punto se marca con un clic.
 */
export const CENTRO_SANTIAGO = { lat: -33.4489, lng: -70.6693 }

export function obtenerPosicionGPS() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('Geolocalización no soportada'))
      return
    }
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        resolve({
          lat: +pos.coords.latitude.toFixed(6),
          lng: +pos.coords.longitude.toFixed(6),
        }),
      (err) => reject(err),
      { timeout: 10000, enableHighAccuracy: true }
    )
  })
}
