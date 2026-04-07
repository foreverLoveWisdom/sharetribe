# transit-ruby removed - using JSON serialization instead (msgpack incompatible with Ruby 3.2+)
module TransitUtils

  module_function

  # Custom JSON encoder that handles UUIDs
  class UUIDEncoder
    def self.encode(obj)
      case obj
      when UUIDTools::UUID
        { '_type' => 'uuid', 'value' => obj.to_s }
      when Hash
        obj.transform_values { |v| encode(v) }
      when Array
        obj.map { |v| encode(v) }
      else
        obj
      end
    end

    def self.decode(obj)
      case obj
      when Hash
        type = obj['_type'] || obj[:_type]
        if type == 'uuid'
          value = obj['value'] || obj[:value]
          UUIDTools::UUID.parse(value)
        else
          obj.transform_values { |v| decode(v) }
        end
      when Array
        obj.map { |v| decode(v) }
      else
        obj
      end
    end
  end

  # Encode content to JSON (encoding parameter kept for API compatibility)
  def encode(content, encoding = :json)
    encoded_content = UUIDEncoder.encode(content)
    JSON.generate(encoded_content)
  end

  # Decode content from JSON (encoding parameter kept for API compatibility)
  def decode(content, encoding = :json)
    parsed_content = JSON.parse(content, symbolize_names: true)
    UUIDEncoder.decode(parsed_content)
  end

end
