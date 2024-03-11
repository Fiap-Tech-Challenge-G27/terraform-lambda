import { Client } from "pg";
import { sign } from "jsonwebtoken";
import { log } from "console";

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
  const client = new Client({
    host: process.env.POSTGRES_HOST,
    port: process.env.POSTGRES_PORT,
    database: process.env.DATABASE,
    user: process.env.USER,
    password: process.env.PASSWORD,
  });

  client.connect();

  const { rows } = await client.query(
    `SELECT * FROM public."customers" WHERE cpf = '${cpf}'`
  );

  client.end();

  const user = rows[0];

  return user;
}

function generateJwt(user: any) {
  const jwtSecret = process.env.JWT_SECRET;

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