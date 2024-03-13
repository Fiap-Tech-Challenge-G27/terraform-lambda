import { Client } from "pg";
import { sign } from "jsonwebtoken";
import { log } from "console";
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from ("@aws-sdk/client-screts-manager");

const clientSecrets = new SecretsManagerClient({
  region: "us-east-1",
});

export const handler = async (event: any): Promise<any> => {
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

  const token = generateJwt(user);

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

async function getCustomerByCpf(cpf: string): Promise<any> {
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

  const client = new Client({
    host: response.host,
    port: response.port,
    database: response.db,
    user: response.username,
    password: response.password,
  });

  client.connect();

  const { rows } = await client.query(
    `SELECT * FROM public."customers" WHERE cpf = '${cpf}'`
  );

  client.end();

  const user = rows[0];

  return user;
}

async function generateJwt(user: any) {
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

  const jwtSecret = response.jwtSecret;

  console.log("jwtSecret", jwtSecret);

  let token = sign(
    {
      data: user,
    },
    String(jwtSecret),
    { expiresIn: "1h" }
  );

  log("token", token);

  return token;
}