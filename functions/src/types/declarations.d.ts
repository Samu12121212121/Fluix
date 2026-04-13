/**
 * Declaraciones ambientales para módulos sin tipos instalados en node_modules.
 * Estos módulos SÍ están en package.json; este archivo permite compilar TypeScript
 * aunque `npm install` no haya generado las definiciones de tipos todavía.
 */

declare module "node-fetch" {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const fetch: (url: string, init?: any) => Promise<any>;
  export default fetch;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class Headers implements Iterable<[string, string]> { [Symbol.iterator](): Iterator<[string, string]>; [key: string]: any; }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class Response { ok: boolean; status: number; statusText: string; headers: Headers; json(): Promise<any>; text(): Promise<string>; buffer(): Promise<Buffer>; [key: string]: any; }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class Request { [key: string]: any; }
}

declare module "sharp" {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  function sharp(input?: any, options?: any): any;
  export = sharp;
}

declare module "@google-cloud/secret-manager" {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class SecretManagerServiceClient { [key: string]: any; }
}

