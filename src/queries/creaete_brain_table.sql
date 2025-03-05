CREATE EXTENSION vector;
DROP TABLE IF EXISTS "bot-brain";
CREATE TABLE "bot-brain" (
  id VARCHAR(150),
  text VARCHAR(5000),
  page_number INTEGER,
  source_doc VARCHAR(100),
  embedding vector(768),
  topics VARCHAR[]
);
