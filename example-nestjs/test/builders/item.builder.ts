export class ItemBuilder {
  private id = 'default-id';
  private categoryId = 'default-category-id';

  static anItem(): ItemBuilder {
    return new ItemBuilder();
  }

  withId(id: string): ItemBuilder {
    this.id = id;
    return this;
  }

  withCategoryId(categoryId: string): ItemBuilder {
    this.categoryId = categoryId;
    return this;
  }

  build(): { id: string; categoryId: string } {
    return {
      id: this.id,
      categoryId: this.categoryId,
    };
  }
}
