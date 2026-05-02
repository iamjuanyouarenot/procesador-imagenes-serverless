const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");
const s3 = new S3Client();

exports.handler = async (event) => {
  for (const record of event.Records) {
    // SQS nos pasa el evento de S3 dentro de su body
    const sqsBody = JSON.parse(record.body);
    const s3Event = sqsBody.Records[0];
    const srcBucket = s3Event.s3.bucket.name;
    const srcKey = decodeURIComponent(s3Event.s3.object.key.replace(/\+/g, " "));

    // 1. Descargar imagen
    const getObj = await s3.send(new GetObjectCommand({ Bucket: srcBucket, Key: srcKey }));
    const streamToBuffer = async (stream) => {
      const chunks = [];
      for await (const chunk of stream) chunks.push(chunk);
      return Buffer.concat(chunks);
    };
    const imageBuffer = await streamToBuffer(getObj.Body);

    // 2. Recortar a círculo de 40x40
    const processedBuffer = await sharp(imageBuffer)
      .resize(40, 40)
      .composite([{
        input: Buffer.from(`<svg><circle cx="20" cy="20" r="20" /></svg>`),
        blend: 'dest-in'
      }])
      .png()
      .toBuffer();

    // 3. Subir a processed/
    const destKey = srcKey.replace("uploads/", process.env.PROCESSED_PREFIX);
    await s3.send(new PutObjectCommand({
      Bucket: process.env.S3_BUCKET,
      Key: destKey,
      Body: processedBuffer,
      ContentType: "image/png"
    }));
  }
  return {};
};