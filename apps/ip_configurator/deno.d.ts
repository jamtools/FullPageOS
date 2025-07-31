// // Type definitions for Deno
// declare namespace Deno {
//   export function readTextFile(path: string): Promise<string>;
//   export function writeTextFile(path: string, data: string): Promise<void>;
//   export function serve(handler: (request: Request) => Response | Promise<Response>): void;
// }

// // Type definitions for Hono
// declare module 'hono' {
//   export class Hono {
//     constructor();
//     get(path: string, handler: (c: any) => any): this;
//     post(path: string, handler: (c: any) => any): this;
//     fetch: (request: Request) => Promise<Response>;
//   }
// }
