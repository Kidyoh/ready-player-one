export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
  ) {
    super(message);
  }
}

export const notFound = (what: string) => new HttpError(404, `${what} not found`);
export const badRequest = (message: string) => new HttpError(400, message);
export const conflict = (message: string) => new HttpError(409, message);
export const forbidden = (message = 'Not allowed') => new HttpError(403, message);
