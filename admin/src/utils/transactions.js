export function getTransactionOwnerId(transactionRef) {
  const ownerRef = transactionRef?.parent?.parent;
  if (
    ownerRef?.parent?.id !== 'users'
    || typeof ownerRef.id !== 'string'
    || ownerRef.id.length === 0
  ) {
    return null;
  }

  return ownerRef.id;
}

export function mapTransactionDocument(document) {
  return {
    id: document.id,
    ...document.data(),
    userId: getTransactionOwnerId(document.ref),
  };
}
