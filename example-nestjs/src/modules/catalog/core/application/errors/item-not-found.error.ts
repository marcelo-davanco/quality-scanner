/**
 * Error thrown when an item ID provided in the request does not exist
 * in the catalog's item list.
 * Returns a 400 Bad Request to the client with a generic message,
 * while storing detailed information for logging/audit purposes.
 */
export class ItemNotFoundError extends Error {
  readonly statusCode = 400;
  readonly clientMessage: string;
  readonly detailedInfo: {
    requestedId: string;
    availableItems: { id: string; categoryId: string }[];
  };

  constructor(requestedId: string, availableItems: { id: string; categoryId: string }[]) {
    const message = `Item with ID "${requestedId}" not found`;
    super(message);
    Object.setPrototypeOf(this, ItemNotFoundError.prototype);
    this.name = 'ItemNotFoundError';

    this.clientMessage = `O item solicitado não foi encontrado. Verifique o ID fornecido.`;
    this.detailedInfo = {
      requestedId,
      availableItems
    };
  }
}
