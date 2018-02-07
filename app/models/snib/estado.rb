class Estado < ActiveRecord::Base
  establish_connection(:snib)
  self.primary_key = 'entid'

  scope :campos_min, -> { select('entid AS region_id, entidad AS nombre_region').order(entidad: :asc) }
  scope :centroide, -> { select('st_x(st_centroid(the_geom)) AS long, st_y(st_centroid(the_geom)) AS lat') }
  scope :geojson_select, -> { select('ST_AsGeoJSON(the_geom) AS geojson') }
  scope :campos_geom, -> { centroide.geojson_select }
  scope :geojson, ->(region_id) { geojson_select.where(entid: region_id) }

  # Esta correspondencia no deberia existir pero las regiones en el snib las hicieron con las patas
  CORRESPONDENCIA = [nil, '08', '01', '07', '23', '26', '10', '32', '16', '13', '24', '25', '04',
                     '06', '31', '12', '20', '18', '14', '02', '19', '21', '15', '27', '03', '11',
                      '22', '30', '05', '28', '09', '29', '17']
end