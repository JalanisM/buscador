class Fichas::Legislacion < Ficha

	self.table_name = "#{CONFIG.bases.fichasespecies}.legislacion"
	self.primary_keys = :legislacionId,  :especieId

	belongs_to :taxon, :class_name => 'Fichas::Taxon', :foreign_key => 'especieId'

end
