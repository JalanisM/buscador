require 'rubygems'
require 'trollop'

OPTS = Trollop::options do
  banner <<-EOS
Completa el campo ancestry.

*** Popula la base de datos metamares con una tabla llamada "metadata" que son datos de su excel,
*** Correr este script si se desea migrar de nuevo hay que trucar las tablas de metamares o subir un respaldo limpio

Usage:

  rails r db/metamares/migracion_base/migracion_mysql.rb -d

where [options] are:
  EOS
  opt :debug, 'Print debug statements', :type => :boolean, :short => '-d'
end

def itera_metadata
  puts 'Iniciando la funcion itera_metadata ...' if OPTS[:debug]
  Metamares::Metadata.all.each do |meta|
    puts "\tRecord: #{meta.mmid}  ..." if OPTS[:debug]

    proyecto = Metamares::Proyecto.new
    proyecto.id = meta.mmid
    proyecto.nombre_proyecto = meta.short_title
    proyecto.autor = meta.author unless meta.author.estandariza == 'na'
    proyecto.financiamiento = meta.research_fund unless meta.research_fund.estandariza == 'na'
    proyecto.campo_investigacion = meta.research_field unless meta.research_field.estandariza == 'na'
    proyecto.campo_ciencia = meta.science unless meta.science.estandariza == 'na'

    # Institucion
    if institucion = Metamares::Institucion.where(slug: meta.institution.estandariza).first
      proyecto.institucion_id = institucion.id
    else
      institucion = Metamares::Institucion.new
      institucion.nombre_institucion = meta.institution
      institucion.tipo = meta.institution_type unless meta.institution_type.estandariza == 'na'
      institucion.slug = meta.institution.estandariza

      # Para dividir el contacto
      contacto = meta.user_contact
      contacto_datos = contacto.split(';')

      if contacto.estandariza.present? && contacto.estandariza != 'na' && contacto_datos.length > 1
        institucion.contacto = contacto_datos[0].strip unless contacto_datos[0].estandariza == 'na'
        institucion.correo_contacto = contacto_datos[1].strip unless contacto_datos[1].estandariza == 'na'
      end

      if institucion.save
        proyecto.institucion_id = institucion.id
      end
    end

    # Region
    region = Metamares::RegionM.new
    region.nombre_region = meta.region unless meta.region.estandariza == 'na'
    region.nombre_zona = meta.area unless meta.area.estandariza == 'na'
    region.nombre_ubicacion = meta.location unless meta.location.estandariza == 'na'
    region.latitud = meta.lat unless meta.lat.to_i == 0
    region.longitud = meta.lon unless meta.lon.to_i == 0

    if region.save
      proyecto.region_id = region.id
    end

    # Periodo
    periodo = Metamares::Periodo.new
    periodo.monitoreo_desde = "#{meta.start_year}/01/01" unless meta.start_year == 0
    periodo.monitoreo_hasta = "#{meta.end_year}/01/01" unless meta.end_year == 0

    if periodo.save
      proyecto.periodo_id = periodo.id
    end

    # Datos
    dato = Metamares::Dato.new
    dato.estatus_datos = meta.dataset_available
    dato.numero_ejemplares = meta.data_time_points unless meta.data_time_points == 0
    dato.tipo_unidad = meta.unit_type unless meta.unit_type.estandariza == 'na'
    dato.resolucion_temporal = meta.temporal_resolution unless meta.temporal_resolution.estandariza == 'na'
    dato.resolucion_espacial = meta.spatial_resolution unless meta.spatial_resolution.estandariza == 'na'
    dato.titulo_compilacion = meta.compilation_title unless meta.compilation_title.estandariza == 'na'
    dato.titulo_conjunto_datos = meta.dataset_title unless meta.dataset_title.estandariza == 'na'
    dato.publicacion_anio = "#{meta.publication_year}/01/01" unless meta.publication_year == 0
    dato.descarga_datos = meta.reference unless meta.reference.estandariza == 'na'
    dato.notas_adicionales = meta.notes unless meta.notes.estandariza == 'na'
    dato.interaccion = meta.se_interaction unless meta.se_interaction.estandariza == 'na'

    if dato.save
      proyecto.dato_id = dato.id
    end

    if proyecto.save
      if meta.keywords.estandariza.present? && meta.keywords.estandariza != 'na' # Keywords
        con_punto_coma = meta.keywords.split(';')
        con_coma = meta.keywords.split(',')

        mas_keywords = con_coma.length > con_punto_coma.length ? con_coma : con_punto_coma
        mas_keywords.each do |nombre_keyword|
          next unless nombre_keyword.strip.present?
          k = proyecto.keywords.new
          k.nombre_keyword = nombre_keyword.strip
          k.save
        end
      end

      # Especie o subject name
      if meta.subject_name.estandariza.present? && meta.subject_name.estandariza != 'na'
        e = proyecto.especies.new

        if taxon = Especie.solo_publicos.where("LOWER(#{Especie.attribute_alias(:nombre_cientifico)}) = ?", meta.subject_name.limpia.downcase).first
          e.especie_id = taxon.id
        else
          e.nombre_cientifico = meta.subject_name
        end

        e.save
      end
    end

  end  # End each do meta
end


start_time = Time.now

itera_metadata

puts "Termino en #{Time.now - start_time} seg" if OPTS[:debug]