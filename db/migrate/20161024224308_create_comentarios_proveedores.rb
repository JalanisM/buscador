class CreateComentariosProveedores < ActiveRecord::Migration
  def change
    create_table :comentarios_proveedores do |t|
      t.string :comentario_id, limit: 10, null: false
      t.string :proveedor_id, null: false
      t.timestamps
    end
  end
end
