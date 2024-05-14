const { MongoClient } = require('mongodb');
const { sign } = require("jsonwebtoken");
const { log } = require("console");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const clientSecrets = new SecretsManagerClient({
  region: "us-east-1",
});

const handler = async (event) => {

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

  const user = await getCustomerByCpf(cpf);

  if (!user) {
    return {
      statusCode: 404,
      body: JSON.stringify({ error: "User not found" }),
    };
  }

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
  const secret_name = "dbcredentials";

  let response;

  try {
    response = await clientSecrets.send(
      new GetSecretValueCommand({
        SecretId: secret_name,
        VersionStage: "AWSCURRENT",
      })
    );
  } catch (error) {
    throw error;
  }


  const credentials = JSON.parse(response.SecretString);


  console.log(credentials)

  const client = new MongoClient(credentials.uri, { useNewUrlParser: true, useUnifiedTopology: true });

  try {
    await client.connect();

    const db = client.db(credentials.db);
    const collection = db.collection('customers');
    const user = await collection.findOne({ cpf: cpf });

    return user;
    
  } catch (error) {
    throw error;
  } finally {
    await client.close();
  }
}

async function generateJwt(user) {
  const secret_name = "jwt_credentials";

  let response;

  try {
    response = await clientSecrets.send(
      new GetSecretValueCommand({
        SecretId: secret_name,
        VersionStage: "AWSCURRENT",
      })
    );
  } catch (error) {
    throw error;
  }


  const credentials = JSON.parse(response.SecretString);

  const jwtSecret = credentials.jwtSecret;

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