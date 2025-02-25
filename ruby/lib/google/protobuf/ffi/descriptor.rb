# Protocol Buffers - Google's data interchange format
# Copyright 2022 Google Inc.  All rights reserved.
# https://developers.google.com/protocol-buffers/
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Google
  module Protobuf
    ##
    # Message Descriptor - Descriptor for short.
    class Descriptor
      attr :descriptor_pool, :msg_class
      include Enumerable

      # FFI Interface methods and setup
      extend ::FFI::DataConverter
      native_type ::FFI::Type::POINTER

      class << self
        prepend Google::Protobuf::Internal::TypeSafety
        include Google::Protobuf::Internal::PointerHelper

        # @param value [Descriptor] Descriptor to convert to an FFI native type
        # @param _ [Object] Unused
        def to_native(value, _ = nil)
          msg_def_ptr = value.nil? ? nil : value.instance_variable_get(:@msg_def)
          return ::FFI::Pointer::NULL if msg_def_ptr.nil?
          raise "Underlying msg_def was null!" if msg_def_ptr.null?
          msg_def_ptr
        end

        ##
        # @param msg_def [::FFI::Pointer] MsgDef pointer to be wrapped
        # @param _ [Object] Unused
        def from_native(msg_def, _ = nil)
          return nil if msg_def.nil? or msg_def.null?
          file_def = Google::Protobuf::FFI.get_message_file_def msg_def
          descriptor_from_file_def(file_def, msg_def)
        end
      end

      def to_native
        self.class.to_native(self)
      end

      ##
      # Great write up of this strategy:
      # See https://blog.appsignal.com/2018/08/07/ruby-magic-changing-the-way-ruby-creates-objects.html
      def self.new(*arguments, &block)
        raise "Descriptor objects may not be created from Ruby."
      end

      def to_s
        inspect
      end

      def inspect
        "Descriptor - (not the message class) #{name}"
      end

      def file_descriptor
        @descriptor_pool.send(:get_file_descriptor, Google::Protobuf::FFI.get_message_file_def(@msg_def))
      end

      def name
        @name ||= Google::Protobuf::FFI.get_message_fullname(self)
      end

      def each_oneof &block
        n = Google::Protobuf::FFI.oneof_count(self)
        0.upto(n-1) do |i|
          yield(Google::Protobuf::FFI.get_oneof_by_index(self, i))
        end
        nil
      end

      def each &block
        n = Google::Protobuf::FFI.field_count(self)
        0.upto(n-1) do |i|
          yield(Google::Protobuf::FFI.get_field_by_index(self, i))
        end
        nil
      end

      def lookup(name)
        Google::Protobuf::FFI.get_field_by_name(self, name, name.size)
      end

      def lookup_oneof(name)
        Google::Protobuf::FFI.get_oneof_by_name(self, name, name.size)
      end

      def msgclass
        @msg_class ||= build_message_class
      end

      private

      extend Google::Protobuf::Internal::Convert

      def initialize(msg_def, descriptor_pool)
        @msg_def = msg_def
        @msg_class = nil
        @descriptor_pool = descriptor_pool
      end

      def self.private_constructor(msg_def, descriptor_pool)
        instance = allocate
        instance.send(:initialize, msg_def, descriptor_pool)
        instance
      end

      def wrapper?
        if defined? @wrapper
          @wrapper
        else
          @wrapper = case Google::Protobuf::FFI.get_well_known_type self
          when :DoubleValue, :FloatValue, :Int64Value, :UInt64Value, :Int32Value, :UInt32Value, :StringValue, :BytesValue, :BoolValue
            true
          else
            false
          end
        end
      end

      def self.get_message(msg, descriptor, arena)
        return nil if msg.nil? or msg.null?
        message = OBJECT_CACHE.get(msg.address)
        if message.nil?
          message = descriptor.msgclass.send(:private_constructor, arena, msg: msg)
        end
        message
      end

      def pool
        @descriptor_pool
      end
    end

    class FFI
      # MessageDef
      attach_function :new_message_from_def, :upb_Message_New,                        [Descriptor, Internal::Arena], :Message
      attach_function :field_count,          :upb_MessageDef_FieldCount,              [Descriptor], :int
      attach_function :get_message_file_def, :upb_MessageDef_File,                    [:pointer], :FileDef
      attach_function :get_message_fullname, :upb_MessageDef_FullName,                [Descriptor], :string
      attach_function :get_mini_table,       :upb_MessageDef_MiniTable,               [Descriptor], MiniTable.ptr
      attach_function :oneof_count,          :upb_MessageDef_OneofCount,              [Descriptor], :int
      attach_function :get_well_known_type,  :upb_MessageDef_WellKnownType,           [Descriptor], WellKnown
      attach_function :message_def_syntax,   :upb_MessageDef_Syntax,                  [Descriptor], Syntax
      attach_function :find_msg_def_by_name, :upb_MessageDef_FindByNameWithSize,      [Descriptor, :string, :size_t, :FieldDefPointer, :OneofDefPointer], :bool
    end
  end
end
