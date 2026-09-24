import { build } from "esbuild"
import * as babel from "@babel/core"
import solid from "babel-preset-solid"
import { readFile } from "node:fs/promises"

const compileJsx = {
  name: "solid",
  setup(builder) {
    builder.onLoad({ filter: /\.jsx$/ }, async ({ path }) => {
      const source = await readFile(path, "utf8")
      const out = await babel.transformAsync(source, {
        filename: path,
        presets: [[solid, {}]],
        babelrc: false,
        configFile: false,
        sourceMaps: false,
      })
      return { contents: out.code, loader: "js" }
    })
  },
}

const [entry = "src/main.jsx", outfile = "dist/app.js"] = process.argv.slice(2)

await build({
  entryPoints: [entry],
  bundle: true,
  format: "esm",
  target: "es2022",
  minify: !outfile.includes("/.built/"),
  outfile,
  plugins: [compileJsx],
  external: ["*.woff2"],
  legalComments: "none",
})
