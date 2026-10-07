import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import sharp from 'sharp';

const almacenamiento = new S3Client({});
const mascara = Buffer.from('<svg width="40" height="40"><circle cx="20" cy="20" r="20" fill="white"/></svg>');

async function recortar(registro) {
  if (registro.eventSource !== 'aws:s3' || !registro.eventName?.startsWith('ObjectCreated:')) {
    throw new Error('El registro no corresponde a la creación de un objeto de S3.');
  }
  const bucket = registro.s3?.bucket?.name;
  const clave = decodeURIComponent(registro.s3?.object?.key?.replace(/\+/g, ' ') ?? '');
  if (bucket !== process.env.S3_BUCKET || !clave.startsWith(process.env.UPLOAD_PREFIX)) {
    throw new Error('El objeto no pertenece al prefijo original del proyecto.');
  }
  const original = await almacenamiento.send(new GetObjectCommand({ Bucket: bucket, Key: clave }));
  if (original.ContentLength > 10 * 1024 * 1024) throw new Error('La imagen original supera los 10 MiB.');
  const imagen = await original.Body.transformToByteArray();
  const procesada = await sharp(Buffer.from(imagen), { limitInputPixels: 40000000 })
    .rotate()
    .resize(40, 40, { fit: 'cover' })
    .ensureAlpha()
    .composite([{ input: mascara, blend: 'dest-in' }])
    .png()
    .toBuffer();
  const nombre = clave.slice(process.env.UPLOAD_PREFIX.length).replace(/\.[^/.]+$/, '');
  const destino = `${process.env.PROCESSED_PREFIX}${nombre}.png`;
  try {
    await almacenamiento.send(new PutObjectCommand({
      Bucket: bucket,
      Key: destino,
      Body: procesada,
      ContentType: 'image/png',
      IfNoneMatch: '*'
    }));
  } catch (error) {
    if (error.$metadata?.httpStatusCode !== 412) throw error;
    console.info(JSON.stringify({ mensaje: 'El recorte ya existe.', clave: destino }));
    return;
  }
  console.info(JSON.stringify({ mensaje: 'Imagen circular de 40 por 40 píxeles guardada.', original: clave, procesada: destino }));
}

export const ejecutar = async evento => {
  const fallos = [];
  for (const mensaje of evento.Records ?? []) {
    try {
      const notificacion = JSON.parse(mensaje.body);
      if (notificacion.Event === 's3:TestEvent') {
        console.info('Notificación de prueba de S3 recibida.');
        continue;
      }
      if (!Array.isArray(notificacion.Records) || !notificacion.Records.length) {
        throw new Error('El mensaje no contiene registros de S3.');
      }
      for (const registro of notificacion.Records) await recortar(registro);
    } catch (error) {
      console.error(JSON.stringify({ mensaje: 'No se pudo procesar el mensaje de imagen.', mensaje_id: mensaje.messageId, tipo_error: error.name }));
      fallos.push({ itemIdentifier: mensaje.messageId });
    }
  }
  return { batchItemFailures: fallos };
};
