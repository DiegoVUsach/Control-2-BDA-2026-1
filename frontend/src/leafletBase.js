/**
 * Configuracion base de Leaflet compartida por los componentes de mapa.
 * Corrige la ruta de los iconos por defecto (problema conocido de Leaflet
 * con empaquetadores como Vite) importandolos como assets del bundle.
 */
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import iconRetinaUrl from 'leaflet/dist/images/marker-icon-2x.png'
import iconUrl from 'leaflet/dist/images/marker-icon.png'
import shadowUrl from 'leaflet/dist/images/marker-shadow.png'

delete L.Icon.Default.prototype._getIconUrl
L.Icon.Default.mergeOptions({ iconRetinaUrl, iconUrl, shadowUrl })

export default L
