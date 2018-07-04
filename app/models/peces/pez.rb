class Pez < ActiveRecord::Base

  establish_connection(Rails.env.to_sym)
  self.table_name='peces'
  self.primary_key='especie_id'

  has_many :peces_criterios, :class_name => 'PezCriterio', :foreign_key => :especie_id, dependent: :destroy#, inverse_of: :pez
  has_many :criterios, :through => :peces_criterios, :source => :criterio
  has_many :criterio_propiedades, :through => :criterios, :source => :propiedad

  has_many :peces_propiedades, :class_name => 'PezPropiedad', :foreign_key => :especie_id
  has_many :propiedades, :through => :peces_propiedades, :source => :propiedad

  belongs_to :especie

  scope :select_joins_peces, -> { select([:nombre_cientifico, :nombres_comunes, :valor_total, :valor_zonas, :imagen, :con_estrella]).select('peces.especie_id') }

  scope :join_criterios,-> { joins('LEFT JOIN peces_criterios ON peces.especie_id=peces_criterios.especie_id LEFT JOIN criterios on peces_criterios.criterio_id = criterios.id') }
  scope :join_propiedades,-> { joins('LEFT JOIN peces_propiedades ON peces.especie_id=peces_propiedades.especie_id LEFT JOIN propiedades on peces_propiedades.propiedad_id = propiedades.id') }

  scope :join_criterios_propiedades,-> { joins('LEFT JOIN propiedades on criterios.propiedad_id = propiedades.id') }

  scope :filtros_peces, -> { select_joins_peces.join_criterios.join_propiedades.distinct.order(con_estrella: :desc).order(:valor_total, :tipo_imagen, :nombre_cientifico) }

  scope :nombres_peces, -> { select([:especie_id, :nombre_cientifico, :nombres_comunes])}
  scope :nombres_cientificos_peces, -> { select(:especie_id).select("nombre_cientifico as label")}
  scope :nombres_comunes_peces, -> { select(:especie_id).select("nombres_comunes as label")}

  validates_presence_of :especie_id
  attr_accessor :guardar_manual, :anio, :valor_por_zona
  before_save :actualiza_pez, unless: :guardar_manual
  after_save :guarda_valor_zonas_y_total, unless: :guardar_manual

  accepts_nested_attributes_for :peces_criterios, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :peces_propiedades, reject_if: :all_blank, allow_destroy: true

  # Corre los metodos necesarios para actualizar el pez
  def actualiza_pez
    guarda_nom_iucn
    asigna_nombre_cientifico
    asigna_nombres_comunes
    asigna_imagen
    guarda_redis
  end

  # Guarda el redis del pez aprovechando el metodo empaquetado de especie
  def guarda_redis
    especie.guarda_redis(loader: 'peces', foto_principal: imagen)
  end

  # Actualiza todos los servicios
  def self.actualiza_todo
    all.each do |p|
      p.guardar_manual = true
      p.actualiza_pez
      p.save if p.changed?
    end
  end

  # Asigna los valores promedio por zona, de acuerdo a cada estado
  def guarda_valor_zonas_y_total
    asigna_valor_zonas_y_total
    self.guardar_manual = true
    save if valid?
  end

  # Asigna los valores promedio por zona, de acuerdo a todos los criterios
  def asigna_valor_zonas_y_total
    asigna_anio
    valores_por_zona

    criterio_propiedades.select('propiedades.*, valor').cnp.where('anio=?', anio).each do |propiedad|
      zona_num = propiedad.parent.nombre_zona_a_numero  # Para obtener la posicion de la zona

      if propiedad.nombre_propiedad == 'No se distribuye'  # Quitamos la zona
        self.valor_por_zona[zona_num] = 'n'
      elsif propiedad.nombre_propiedad == 'Estatus no definido' # La zona se muestra en gris
        self.valor_por_zona[zona_num] = 's'
      else
        self.valor_por_zona[zona_num] = valor_por_zona[zona_num] + propiedad.valor
      end
    end

    self.valor_zonas = valor_zona_a_color.join('')
    self.valor_total = color_zona_a_valor.inject(:+)
  end

  def self.actualiza_todo_valor_zonas_y_total
    all.each do |p|
      p.guardar_manual = true
      p.guarda_valor_zonas_y_total
    end
  end

  # Asigna los valores de la nom de acuerdo a catalogos
  def guarda_nom_iucn
    asigna_anio

    # Para actualizar o crear el valor de la nom
    criterio_id = if nom = especie.catalogos.nom.first
                    if prop = Propiedad.where(nombre_propiedad: nom.descripcion).first
                      if crit = prop.criterios.where('anio=?', 2012).first
                        crit.id
                      else
                        158
                      end
                    end

                  else
                    158
                  end


    if crit = criterios.where('anio=?', 2012).nom.first
      pez_crit = peces_criterios.where(criterio_id: crit.id).first
      pez_crit.criterio_id = criterio_id
    else
      pez_crit = peces_criterios.new
      pez_crit.criterio_id = criterio_id # No aplica
    end

    pez_crit.save if pez_crit.changed?

    # Para actualizar o crear el valor de iucn
    criterio_id = if iucn = especie.catalogos.iucn.first
                    if prop = Propiedad.where(nombre_propiedad: iucn.descripcion).first
                      if crit = prop.criterios.where('anio=?', 2012).first
                        crit.id
                      else
                        159
                      end
                    end

                  else
                    159
                  end


    if crit = criterios.where('anio=?', 2012).iucn.first
      pez_crit = peces_criterios.where(criterio_id: crit.id).first
      pez_crit.criterio_id = criterio_id
    else
      pez_crit = peces_criterios.new
      pez_crit.criterio_id = criterio_id # No aplica
    end

    pez_crit.save if pez_crit.changed?
  end

  def self.actualiza_todo_nom_iucn
    all.each do |p|
      p.guardar_manual = true
      p.guarda_nom_iucn
    end
  end

  def guarda_imagen
    asigna_imagen
    save if changed?
  end

  # Asigna la ilustracion, foto o ilustracion, asi como el tipo de foto
  def asigna_imagen
    # Trata de asignar la ilustracion
    bdi = BDIService.new
    res = bdi.dameFotos(taxon: especie, campo: 528, autor: 'Sergio de la Rosa Martínez', autor_campo: 80, ilustraciones: true)

    if res[:estatus] == 'OK'
      if res[:fotos].any?
        self.imagen = res[:fotos].first.medium_url
        self.tipo_imagen = 1
        return
      end
    end

    # Trata de asignar la foto principal
    if a = especie.adicional
      foto = a.foto_principal

      if foto.present?
        self.imagen = foto
        self.tipo_imagen = 2
        return
      end
    end

    # Asignar la silueta
    self.imagen = '/assets/app/peces/silueta.png'
    self.tipo_imagen = 3
  end

  def self.actualiza_todo_imagen
    all.each do |p|
      p.guardar_manual = true
      p.guarda_imagen
    end
  end

  # BORRAR en centralizacion
  def guarda_nombre_cientifico
    asigna_nombre_cientifico
    save if changed?
  end

  # BORRAR en centralizacion
  def asigna_nombre_cientifico
    self.nombre_cientifico = especie.nombre_cientifico
  end

  # BORRAR en centralizacion
  def self.actualiza_todo_nombre_cientifico
    all.each do |p|
      p.guardar_manual = true
      p.guarda_nombre_cientifico
    end
  end

  # BORRAR en centralizacion
  def guarda_nombres_comunes
    asigna_nombres_comunes
    save if changed?
  end

  # BORRAR en centralizacion
  def asigna_nombres_comunes
    nombres = especie.nombres_comunes_todos.map{|e| e.values.flatten}.flatten.join(',')
    self.nombres_comunes = nombres if nombres.present?
  end

  # BORRAR en centralizacion
  def self.actualiza_todo_nombres_comunes
    all.each do |p|
      p.guardar_manual = true
      p.guarda_nombres_comunes
    end
  end


  private

  # Asocia el valor por zona a un color correspondiente
  def valor_zona_a_color
    valor_por_zona.each_with_index do |zona, i|
      next unless zona.class == Fixnum # Por si ya tiene asignada una letra

      case zona
      when -5..4
        self.valor_por_zona[i] = 'v'
      when 5..19
        self.valor_por_zona[i] = 'a'
      when 20..100
        self.valor_por_zona[i] = 'r'
      end
    end
  end

  # Este valor es solo de referencia para el valor total
  def color_zona_a_valor
    zonas = []

    valor_zonas.split('').each do |zona|
      case zona
      when 'v'
        zonas << -100
      when 'a'
        zonas << 10
      when 'r'
        zonas << 100
      when 'n', 's'
        zonas << 0
      end
    end

    zonas
  end

  # Para sacar solo el año en cuestion
  def asigna_anio
    self.anio = anio || CONFIG.peces.anio || 2012
  end

  # El valor de los criterios sin la CNP
  def valores_por_zona
    asigna_anio
    valor = 0

    propiedades = criterio_propiedades.select('valor').where('anio=?', anio)
    valor+= propiedades.tipo_capturas.map(&:valor).inject(:+).to_i
    valor+= propiedades.tipo_vedas.map(&:valor).inject(:+).to_i
    valor+= propiedades.procedencias.map(&:valor).inject(:+).to_i
    valor+= propiedades.nom.map(&:valor).inject(:+).to_i
    valor+= propiedades.iucn.map(&:valor).inject(:+).to_i

    # Para asignar el campo con_estrella que se asocia a las pesquerias sustentables
    pesquerias = propiedades.pesquerias.map(&:valor).inject(:+).to_i
    valor+= pesquerias
    self.con_estrella = 1 if pesquerias != 0

    self.valor_por_zona = Array.new(6, valor)
  end
end