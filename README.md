# xPRESENTx

Este plugin está basado en
[present.nvim](https://github.com/tjdevries/present.nvim), con el añadido de
soporte de imágenes.

![xSSx](assets/xSSx.png)

## Instalar

con **lazy.nvim**

```lua
{
  "frvnzj/xPRESENTx.nvim",
  dependencies = {
    "3rd/image.nvim",
    config = function()
      require("image").setup({
        integrations = {
          markdown = {
            enabled = true,
            clear_in_insert_mode = true,
            download_remote_images = true,
            only_render_image_at_cursor = false,
            filetypes = { "markdown" },
          },
        },
        window_overlap_clear_enabled = true,
        editor_only_render_when_focused = false,
      })
    end,
  },
}
```

### Dependencies

- Terminal con soporte de imágenes (WezTerm, kitty, ghostty)
- image.nvim

## Funcionamiento

Para cambiar a la diapositiva siguiente `n`, diapositiva anterior `p`. Para
terminar la presentación `q`. La ejecución de codeblocks —lua, python,
javascript— con la tecla `X`. Para mayor referencia de configuración vease
[present.nvim](https://github.com/tjdevries/present.nvim).

La imágenes se muestran en la parte inferior derecha, con la tecla `I` la
imagen se abre en grande, para cerrar `:q<cr>`.
