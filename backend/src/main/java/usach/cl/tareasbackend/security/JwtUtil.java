//JwtUtil: fabrica y valida los tokens (HS256, clave simétrica del servidor).

package usach.cl.tareasbackend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;

@Component
public class JwtUtil {
    private final Key key;
    private final long expirationMs;

    public JwtUtil(@Value("${jwt.secret}") String secret,
                   @Value("${jwt.expiration-ms}") long expirationMs) {
        // La clave HS256 se deriva del secreto de configuracion (simetrica:
        // la misma clave firma y verifica; solo el servidor la conoce)
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = expirationMs;
    }

    public String generarToken(int idUsuario, String nombreUsuario) {
        Date ahora = new Date();
        return Jwts.builder()
                .setSubject(nombreUsuario)      // claim estandar "sub"
                .claim("id", idUsuario)         // claim propio: id para autorizar
                .setIssuedAt(ahora)
                .setExpiration(new Date(ahora.getTime() + expirationMs))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();                     // header.payload.firma en Base64
    }

    public Claims validarToken(String token) throws JwtException {
        // parseClaimsJws VERIFICA la firma y la expiracion; si algo falla
        // lanza JwtException (por eso el filtro lo envuelve en try/catch)
        return Jwts.parserBuilder().setSigningKey(key).build()
                .parseClaimsJws(token).getBody();
    }
}