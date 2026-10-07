import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { randomUUID } from 'node:crypto';

const almacenamiento = new S3Client({});
const limite = 4 * 1024 * 1024;
const formatos = {
  'image/png': { extension: 'png', comprobar: imagen => imagen.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')) },
  'image/jpeg': { extension: 'jpg', comprobar: imagen => imagen.subarray(0, 3).equals(Buffer.from('ffd8ff', 'hex')) },
  'image/gif': { extension: 'gif', comprobar: imagen => ['GIF87a', 'GIF89a'].includes(imagen.subarray(0, 6).toString('ascii')) },
  'image/webp': { extension: 'webp', comprobar: imagen => imagen.subarray(0, 4).toString('ascii') === 'RIFF' && imagen.subarray(8, 12).toString('ascii') === 'WEBP' }
};

const responder = (estado, contenido) => ({
  statusCode: estado,
  headers: { 'content-type': 'application/json; charset=utf-8' },
  body: JSON.stringify(contenido)
});

export const ejecutar = async (evento, contexto) => {
  if (evento.requestContext?.http?.method !== 'POST') {
    return responder(405, { mensaje: 'Utiliza POST para cargar una imagen.' });
  }
  const cabeceras = Object.fromEntries(Object.entries(evento.headers ?? {}).map(([nombre, valor]) => [nombre.toLowerCase(), valor]));
  if (cabeceras['content-type']?.split(';')[0].trim().toLowerCase() !== 'application/json') {
    return responder(415, { mensaje: 'Envía un cuerpo JSON con imagen_base64 y tipo_contenido.' });
  }
  let solicitud;
  try {
    const cuerpo = evento.isBase64Encoded ? Buffer.from(evento.body ?? '', 'base64').toString('utf8') : evento.body;
    solicitud = JSON.parse(cuerpo);
  } catch {
    return responder(400, { mensaje: 'El cuerpo debe contener JSON válido.' });
  }
  const formato = Object.hasOwn(formatos, solicitud?.tipo_contenido) ? formatos[solicitud.tipo_contenido] : undefined;
  if (!formato) return responder(415, { mensaje: 'Los formatos permitidos son PNG, JPEG, GIF y WebP.' });
  const codificada = solicitud.imagen_base64;
  if (typeof codificada !== 'string' || !codificada.length) {
    return responder(400, { mensaje: 'Falta la imagen codificada en base64.' });
  }
  if (codificada.length > 4 * Math.ceil(limite / 3)) {
    return responder(413, { mensaje: 'La imagen supera el límite de 4 MiB.' });
  }
  if (codificada.length % 4 !== 0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(codificada)) {
    return responder(400, { mensaje: 'La codificación base64 no es válida.' });
  }
  const imagen = Buffer.from(codificada, 'base64');
  if (imagen.toString('base64') !== codificada) return responder(400, { mensaje: 'La codificación base64 no es válida.' });
  if (imagen.length > limite) return responder(413, { mensaje: 'La imagen supera el límite de 4 MiB.' });
  if (!formato.comprobar(imagen)) return responder(415, { mensaje: 'El contenido no corresponde al formato declarado.' });
  const clave = `${process.env.UPLOAD_PREFIX}${randomUUID()}.${formato.extension}`;
  try {
    await almacenamiento.send(new PutObjectCommand({
      Bucket: process.env.S3_BUCKET,
      Key: clave,
      Body: imagen,
      ContentType: solicitud.tipo_contenido
    }));
    console.info(JSON.stringify({ mensaje: 'Imagen original guardada.', clave, bytes: imagen.length, solicitud_id: contexto.awsRequestId }));
    return responder(202, { mensaje: 'Imagen recibida para procesamiento.', clave });
  } catch (error) {
    console.error(JSON.stringify({ mensaje: 'No se pudo guardar la imagen.', tipo_error: error.name, solicitud_id: contexto.awsRequestId }));
    return responder(500, { mensaje: 'No se pudo guardar la imagen. Inténtalo nuevamente.' });
  }
};
