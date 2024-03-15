const { Client } = require("pg");
const { sign } = require("jsonwebtoken");
const { log } = require("console");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const clientSecrets = new SecretsManagerClient({
  region: "us-east-1",
});

const handler = async (event) => {
  console.log(event);
  
  if (!event?.body) {
    return {
      statusCode: 422,
      body: JSON.stringify({ error: "Missing body" }),
    };
  }

  const { cpf } = JSON.parse(event.body);

  if (!cpf) {
    return {
      statusCode: 422,
      body: JSON.stringify({ error: "Missing cpf" }),
    };
  }

  console.log("entrou customer")
  const user = await getCustomerByCpf(cpf);

  if (!user) {
    return {
      statusCode: 404,
      body: JSON.stringify({ error: "User not found" }),
    };
  }
  console.log("gerando jwt")

  const token = await generateJwt(user);

  return {
    statusCode: 200,
    body: JSON.stringify(
      {
        access_token: token,
      },
      null,
      2
    ),
  };
};

async function getCustomerByCpf(cpf) {
  const secret_name = "db_credentials";

  let response;

  try {
    response = await clientSecrets.send(
      new GetSecretValueCommand({
        SecretId: secret_name,
        VersionStage: "AWSCURRENT", // VersionStage defaults to AWSCURRENT if unspecified
      })
    );
  } catch (error) {
    throw error;
  }
  
  console.log("pegou secret")
  console.log(response)

  // Aqui, você precisará ajustar como os dados são acessados no `response`. Este exemplo pode não funcionar como esperado pois depende da estrutura do seu secret.
  const credentials = JSON.parse(response.SecretString);
  
    console.log("parse de credentials")

  console.log(credentials)

  const client = new Client({
    host: credentials.host,
    port: credentials.port,
    database: credentials.db,
    user: credentials.username,
    password: credentials.password,
    ssl: true
  });

  client.connect();
  
    console.log("conectando no banco")

try {
    const { rows } = await client.query(
    `SELECT * FROM public."customers" WHERE cpf = '${cpf}'`
  );


    console.log(rows)

  client.end();
    const user = rows[0];

  return user;
  
} catch (error){
  throw error;
}




}

async function generateJwt(user) {
  const secret_name = "jwt_credentials";

  let response;

  try {
    response = await clientSecrets.send(
      new GetSecretValueCommand({
        SecretId: secret_name,
        VersionStage: "AWSCURRENT", // VersionStage defaults to AWSCURRENT if unspecified
      })
    );
  } catch (error) {
    throw error;
  }

  // Aqui, novamente, ajuste conforme a estrutura do seu secret.
  const credentials = JSON.parse(response.SecretString);

  const jwtSecret = credentials.jwtSecret;

  console.log("jwtSecret", jwtSecret);

  let token = sign(
    {
      data: user,
    },
    jwtSecret,
    { expiresIn: "1h" }
  );

  log("token", token);

  return token;
}

module.exports = { handler };