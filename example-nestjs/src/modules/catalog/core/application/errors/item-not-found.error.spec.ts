import { ItemNotFoundError } from './item-not-found.error';
import { ItemBuilder } from '../../../../../../test/builders';

describe('ItemNotFoundError', () => {
  const REQUESTED_ID = 'item-123-uuid';

  it('should be instantiated correctly with all properties defined', () => {
    const item = ItemBuilder.anItem()
      .withId('item-entity-id')
      .withCategoryId('cat-entity-id')
      .build();

    const error = new ItemNotFoundError(REQUESTED_ID, [item]);

    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(ItemNotFoundError);
    expect(error.name).toBe('ItemNotFoundError');
    expect(error.statusCode).toBe(400);
    expect(error.message).toContain(REQUESTED_ID);
  });

  it('should set the generic client message (PT-BR)', () => {
    const error = new ItemNotFoundError('id', []);

    expect(error.clientMessage).toBe(
      'O item solicitado não foi encontrado. Verifique o ID fornecido.',
    );
  });

  it('should serialize detailed info correctly using the provided Items', () => {
    const item1 = ItemBuilder.anItem().withId('id-1').withCategoryId('cat-1').build();
    const item2 = ItemBuilder.anItem().withId('id-2').withCategoryId('cat-2').build();

    const error = new ItemNotFoundError(REQUESTED_ID, [item1, item2]);

    expect(error.detailedInfo).toEqual({
      requestedId: REQUESTED_ID,
      availableItems: [item1, item2],
    });
  });

  it('should maintain the prototype chain for instanceof checks', () => {
    const error = new ItemNotFoundError(REQUESTED_ID, []);

    expect(error).toBeInstanceOf(ItemNotFoundError);
    expect(Object.getPrototypeOf(error)).toBe(ItemNotFoundError.prototype);
  });
});
