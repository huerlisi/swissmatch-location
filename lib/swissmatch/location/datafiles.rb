# encoding: utf-8



require 'swissmatch/loaderror'
require 'swissmatch/name'
require 'swissmatch/canton'
require 'swissmatch/cantons'
require 'swissmatch/district'
require 'swissmatch/districts'
require 'swissmatch/community'
require 'swissmatch/communities'
require 'swissmatch/zipcode'
require 'swissmatch/zipcodes'



module SwissMatch
  module Location

    # Deals with retrieving and updating the files provided by the swiss postal service,
    # and loading the data from them.
    #
    # @todo
    #   The current handling of the urls is not clean. I don't know yet how the urls will
    #   change over iterations.
    class DataFiles

      # Used to generate the regular expressions used to parse the data files.
      # Generates a regular expression, that matches +size+ tab separated fields,
      # delimited by \r\n.
      # @private
      def self.generate_expression(size, separator, terminator)
        /^#{Array.new(size) { "([^#{separator}]*)" }.join(eval("'#{separator}'"))}#{terminator}/
      end

      # Regular expressions used to parse the different files.
      # @private
      Expressions = {
        :community    => generate_expression(4, '\t', '\r\n'),
        :zip_2        => generate_expression(6, '\t', '\r\n'),
        :zip_1        => generate_expression(13, '\t', '\r\n'),
        :districts    => generate_expression(3, ',', '\n'),
        :communities  => generate_expression(10, ',', '\n'),
      }

      # @private
      # The URL of the plz_p1 file
      URLZip1         = "https://match.post.ch/download?file=10001&tid=11&rol=0"

      # @private
      # The URL of the plz_p2 file
      URLZip2         = "https://match.post.ch/download?file=10002&tid=14&rol=0"

      # @private
      # The URL of the plz_c file
      URLCommunity    = "https://match.post.ch/download?file=10003&tid=13&rol=0"

      # @private
      # An array of all urls
      URLAll          = [URLZip1, URLZip2, URLCommunity]

      # The data of all cantons
      # @private
      CantonData = [
        ["AG", "Aargau",                    "Aargau",                   "Argovie",                      "Argovia",                  "Argovia"],
        ["AI", "Appenzell Innerrhoden",     "Appenzell Innerrhoden",    "Appenzell Rhodes-Intérieures", "Appenzello Interno",       "Appenzell Dadens"],
        ["AR", "Appenzell Ausserrhoden",    "Appenzell Ausserrhoden",   "Appenzell Rhodes-Extérieures", "Appenzello Esterno",       "Appenzell Dadora"],
        ["BE", "Bern",                      "Bern",                     "Berne",                        "Berna",                    "Berna"],
        ["BL", "Basel-Landschaft",          "Basel-Landschaft",         "Bâle-Campagne",                "Basilea Campagna",         "Basilea-Champagna"],
        ["BS", "Basel-Stadt",               "Basel-Stadt",              "Bâle-Ville",                   "Basilea Città",            "Basilea-Citad"],
        ["FR", "Freiburg",                  "Fribourg",                 "Fribourg",                     "Friburgo",                 "Friburg"],
        ["GE", "Genève",                    "Genf",                     "Genève",                       "Ginevra",                  "Genevra"],
        ["GL", "Glarus",                    "Glarus",                   "Glaris",                       "Glarona",                  "Glaruna"],
        ["GR", "Graubünden",                "Graubünden",               "Grisons",                      "Grigioni",                 "Grischun"],
        ["JU", "Jura",                      "Jura",                     "Jura",                         "Giura",                    "Giura"],
        ["LU", "Luzern",                    "Luzern",                   "Lucerne",                      "Lucerna",                  "Lucerna"],
        ["NE", "Neuchâtel",                 "Neuenburg",                "Neuchâtel",                    "Neuchâtel",                "Neuchâtel"],
        ["NW", "Nidwalden",                 "Nidwalden",                "Nidwald",                      "Nidvaldo",                 "Sutsilvania"],
        ["OW", "Obwalden",                  "Obwalden",                 "Obwald",                       "Obvaldo",                  "Sursilvania"],
        ["SG", "St. Gallen",                "St. Gallen",               "Saint-Gall",                   "San Gallo",                "Son Gagl"],
        ["SH", "Schaffhausen",              "Schaffhausen",             "Schaffhouse",                  "Sciaffusa",                "Schaffusa"],
        ["SO", "Solothurn",                 "Solothurn",                "Soleure",                      "Soletta",                  "Soloturn"],
        ["SZ", "Schwyz",                    "Schwyz",                   "Schwytz",                      "Svitto",                   "Sviz"],
        ["TG", "Thurgau",                   "Thurgau",                  "Thurgovie",                    "Turgovia",                 "Turgovia"],
        ["TI", "Ticino",                    "Tessin",                   "Tessin",                       "Ticino",                   "Tessin"],
        ["UR", "Uri",                       "Uri",                      "Uri",                          "Uri",                      "Uri"],
        ["VD", "Vaud",                      "Waadt",                    "Vaud",                         "Vaud",                     "Vad"],
        ["VS", "Valais",                    "Wallis",                   "Valais",                       "Vallese",                  "Vallais"],
        ["ZG", "Zug",                       "Zug",                      "Zoug",                         "Zugo",                     "Zug"],
        ["ZH", "Zürich",                    "Zürich",                   "Zurich",                       "Zurigo",                   "Turitg"],
        ["FL", "Fürstentum Liechtenstein",  "Fürstentum Liechtenstein", "Liechtenstein",                "Liechtenstein",            "Liechtenstein"],
        ["DE", "Deutschland",               "Deutschland",              "Allemagne",                    "Germania",                 "Germania"],
        ["IT", "Italien",                   "Italien",                  "Italie",                       "Italia",                   "Italia"],
      ]

      # The directory in which the post mat[ch] files reside
      attr_accessor :data_directory

      # @return [SwissMatch::Cantons] The loaded swiss cantons
      attr_reader :cantons

      # @return [SwissMatch::Districts] The loaded swiss districts
      attr_reader :districts

      # @return [SwissMatch::Communities] The loaded swiss communities
      attr_reader :communities

      # @return [SwissMatch::ZipCodes] The loaded swiss zip codes
      attr_reader :zip_codes

      # @return [Array<LoadError>] Errors that occurred while loading the data
      attr_reader :errors

      # @param [nil, String] data_directory
      #   The directory in which the post mat[ch] files reside
      def initialize(data_directory=nil)
        reset_errors!
        if data_directory then
          @data_directory = data_directory
        elsif ENV['SWISSMATCH_DATA'] then
          @data_directory = ENV['SWISSMATCH_DATA']
        else
          data_directory  = File.expand_path('../../../../data/swissmatch-location', __FILE__)
          data_directory  = Gem.datadir 'swissmatch-location' if defined?(Gem) && !File.directory?(data_directory)
          @data_directory = data_directory
        end
      end

      # Resets the list of errors that were encountered during load
      # @return [self]
      def reset_errors!
        @errors = []
        self
      end

      # Load new files
      #
      # @return [Array<String>]
      #   An array with the absolute file paths of the extracted files.
      def load_updates
        URLAll.flat_map { |url|
          http_get_zip_file(url, @data_directory)
        }
      end

      # Performs an HTTP-GET for the given url, extracts it as a zipped file into the
      # destination directory.
      #
      # @return [Array<String>]
      #   An array with the absolute file paths of the extracted files.
      def http_get_zip_file(url, destination)
        require 'open-uri'
        require 'swissmatch/zip' # patched zip/zip
        require 'fileutils'

        files = []

        open(url) do |zip_buffer|
          Zip::ZipFile.open(zip_buffer) do |zip_file|
            zip_file.each do |f|
              target_path = File.join(destination, f.name)
              FileUtils.mkdir_p(File.dirname(target_path))
              zip_file.extract(f, target_path) unless File.exist?(target_path)
              files << target_path
            end
          end
        end

        files
      end

      # Unzips it as a zipped file into the destination directory.
      def unzip_file(file, destination)
        require 'swissmatch/zip'
        Zip::ZipFile.open(file) do |zip_file|
          zip_file.each do |f|
            target_path = File.join(destination, f.name)
            FileUtils.mkdir_p(File.dirname(target_path))
            zip_file.extract(f, target_path) unless File.exist?(target_path)
          end
        end
      end

      # Used to convert numerical language codes to symbols
      LanguageCodes = [nil, :de, :fr, :it, :rt]

      # Loads the data into this DataFiles instance
      #
      # @return [self]
      #   Returns self.
      def load!
        @cantons, @districts, @communities, @zip_codes = *load
        self
      end

      # @return [Array]
      #   Returns an array of the form [SwissMatch::Cantons, SwissMatch::Communities,
      #   SwissMatch::ZipCodes].
      def load
        reset_errors!

        cantons     = load_cantons
        districts   = load_districts(cantons)
        communities = load_communities(cantons)
        zip_codes   = load_zipcodes(cantons, communities)

        [cantons, districts, communities, zip_codes]
      end

      # @return [SwissMatch::Cantons]
      #   A SwissMatch::Cantons containing all cantons used by the swiss postal service.
      def load_cantons
        Cantons.new(
          CantonData.map { |tag, name, name_de, name_fr, name_it, name_rt|
            Canton.new(tag, name, name_de, name_fr, name_it, name_rt)
          }
        )
      end

      def load_districts(cantons)
        # File format: GDEKT,GDEBZNR,GDEBZNA
        path      = Dir.enum_for(:glob, "#{@data_directory}/districts_*.csv").last
        data      = File.read(path, encoding: Encoding::UTF_8.to_s).scan(Expressions[:districts])
        districts = data[1..-1].map { |canton_tag, district_number, district_name|
          district_number = Integer(district_number, 10)
          canton          = cantons.by_license_tag(canton_tag)

          District.new(district_number, district_name, canton, SwissMatch::Communities.new([]))
        }

        Districts.new(districts)
      end

      # @return [SwissMatch::Communities]
      #   An instance of SwissMatch::Communities containing all communities defined by the
      #   files known to this DataFiles instance.
      def load_communities(cantons)
        raise "Must load cantons first" unless cantons

        file      = Dir.enum_for(:glob, "#{@data_directory}/plz_c_*.txt").last
        temporary = []
        complete  = {}
        load_table(file, :community).each do |bfsnr, name, canton, agglomeration|
          bfsnr         = bfsnr.to_i
          agglomeration = agglomeration.to_i
          canton        = cantons.by_license_tag(canton)
          if agglomeration == bfsnr then
            complete[bfsnr] = Community.new(bfsnr, name, canton, :self)
          elsif agglomeration.nil? then
            complete[bfsnr] = Community.new(bfsnr, name, canton, nil)
          else
            temporary << [bfsnr, name, canton, agglomeration]
          end
        end
        temporary.each do |bfsnr, name, canton, agglomeration|
          community = complete[agglomeration]
          raise "Incomplete community referenced by #{bfsnr}: #{agglomeration}" unless agglomeration
          complete[bfsnr] = Community.new(bfsnr, name, canton, community)
        end

        Communities.new(complete.values)
      end

      # TODO: load all files, not just the most recent
      # TODO: calculate valid_until dates
      #
      # @return [SwissMatch::ZipCodes]
      #   An instance of SwissMatch::ZipCodes containing all zip codes defined by the
      #   files known to this DataFiles instance.
      def load_zipcodes(cantons, communities)
        raise "Must load cantons first" unless cantons
        raise "Must load communities first" unless communities

        temporary         = Hash.new { |h,k| h[k] = [] }
        community_mapping = {}
        self_delivered    = []
        others            = []
        zip1_file         = Dir.enum_for(:glob, "#{@data_directory}/plz_p1_*.txt").last
        zip2_file         = Dir.enum_for(:glob, "#{@data_directory}/plz_p2_*.txt").last
        communities_file  = Dir.enum_for(:glob, "#{@data_directory}/communities_*.csv").last

        # KTKZ,OHW,ORTNAME,GHW,GDENR,GDENAMK,PHW,PLZ4,PLZZ,PLZNAMK
        communities_data  = File.read(
          communities_file,
          encoding: Encoding::UTF_8.to_s
        ).scan(Expressions[:communities])[1..-1].transpose.values_at(4,7,8)
        communities_data[0].map!(&:to_i)
        communities_data[1].map!(&:to_i)
        communities_data[2].map!(&:to_i)
        communities_data.transpose.each do |data|
          temporary[data.last(2)] << data.at(0)
        end

        temporary.each do |key,coms|
          # compact, because some communities already no longer exist, so by_community_numbers can
          # contain nils which must be removed
          community_mapping[key] = Communities.new(communities.by_community_numbers(*coms.uniq.sort).compact)
        end

        temporary         = {}
        load_table(zip1_file, :zip_1).each do |row|
          onrp                  = row.at(0).to_i
          code                  = row.at(2).to_i
          addon                 = row.at(3).to_i
          delivery_by           = row.at(10).to_i
          delivery_by           = case delivery_by when 0 then nil; when onrp then :self; else delivery_by; end
          language              = LanguageCodes[row.at(7).to_i]
          language_alternative  = LanguageCodes[row.at(8).to_i]
          name_short            = Name.new(row.at(4), language)
          name                  = Name.new(row.at(5), language)
          data                  = [
            onrp,                              # ordering_number
            row.at(1).to_i,                    # type
            code,
            addon,
            name,                              # name (official)
            [name],                            # names (official + alternative)
            name_short,                        # name_short (official)
            [name_short],                      # names_short (official + alternative)
            [],                                # PLZ2 type 3 short names (additional region names)
            [],                                # PLZ2 type 3 names (additional region names)
            cantons.by_license_tag(row.at(6)), # canton
            language,
            language_alternative,
            row.at(9) == "1",                  # sortfile_member
            delivery_by,                       # delivery_by
            communities.by_community_number(row.at(11).to_i),  # community_number
            community_mapping[[code, addon]],
            Date.civil(*row.at(12).match(/^(\d{4})(\d\d)(\d\d)$/).captures.map(&:to_i)) # valid_from
          ]
          temporary[onrp] = data
          if :self == delivery_by then
            self_delivered << data
          else
            others << data
          end
        end

        load_table(zip2_file, :zip_2).each do |onrp, rn, type, lang, short, name|
          onrp      = onrp.to_i
          lang_code = lang.to_i
          language  = LanguageCodes[lang_code]
          entry     = temporary[onrp]
          if type == "2"
            entry[5] << Name.new(name, language, rn.to_i)
            entry[7] << Name.new(short, language, rn.to_i)
          elsif type == "3"
            entry[8] << Name.new(name, language, rn.to_i)
            entry[9] << Name.new(short, language, rn.to_i)
          end
        end

        self_delivered.each do |row|
          temporary[row.at(0)] = ZipCode.new(*row)
        end
        others.each do |row|
          if row.at(14) then
            raise "Delivery not found:\n#{row.inspect}" unless tmp = temporary[row.at(14)]
            if tmp.kind_of?(Array) then
              @errors << LoadError.new("Invalid reference: onrp #{row.at(0)} delivery by #{row.at(14)}", row)
              row[14] = nil
            else
              row[14] = tmp
            end
          end
          temporary[row.at(0)] = ZipCode.new(*row)
        end

        ZipCodes.new(temporary.values)
      end

      # Reads a file and parses using the pattern of the given name.
      #
      # @param [String] path
      #   The path of the file to parse
      # @param [Symbol] pattern
      #   The pattern-name used to parse the file (see Expressions)
      #
      # @return [Array<Array<String>>]
      #   A 2 dimensional array representing the tabular data contained in the given file.
      def load_table(path, pattern)
        File.read(path, :encoding => Encoding::Windows_1252.to_s). # to_s because sadly, ruby 1.9.2 can't handle an Encoding instance as argument
          encode(Encoding::UTF_8).
          scan(Expressions[pattern])
      end
    end
  end
end
