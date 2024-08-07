const { MongoClient } = require('mongodb');
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const clientSecrets = new SecretsManagerClient({
  region: "us-east-1"
});

const handler = async (event) => {
  if (!event?.body) {
    return {
      statusCode: 422,
      body: JSON.stringify({ error: "Missing body" }),
    };
  }

  const { cpf, nome, endereco, telefone } = JSON.parse(event.body);

  if (!cpf && !nome && !endereco && !telefone) {
    return {
      statusCode: 422,
      body: JSON.stringify({ error: "At least one identifier (cpf, nome, endereco, telefone) must be provided" }),
    };
  }

  const result = await deleteCustomer({ cpf, nome, endereco, telefone });

  if (!result.deletedCount) {
    return {
      statusCode: 404,
      body: JSON.stringify({ error: "User not found or already deleted" }),
    };
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ message: "User successfully deleted", data: result.deletedData }),
  };
};

async function deleteCustomer(query) {
  const secret_name = "documentdbcredentialsv2";

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

  const client = new MongoClient(credentials.urlCustomers, { retryWrites: false, useNewUrlParser: true, useUnifiedTopology: true });

  try {
    await client.connect();
    const db = client.db(credentials.db);
    const collection = db.collection('customers');
    
    const deletedData = await collection.findOne(query);
    if (!deletedData) {
      return { deletedCount: 0 };
    }
    
    const result = await collection.deleteOne(query);

    return { deletedCount: result.deletedCount, deletedData: deletedData };
    
  } catch (error) {
    throw error;
  } finally {
    await client.close();
  }
}

module.exports = { handler };
