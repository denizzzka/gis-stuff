// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: osm_proto3_format/fileformat.proto

module OSMPBF.fileformat;

import google.protobuf;

enum protocVersion = 3006001;

struct Blob
{
    @Proto(1) bytes raw = protoDefaultValue!bytes;
    @Proto(2) int rawSize = protoDefaultValue!int;
    @Proto(3) bytes zlibData = protoDefaultValue!bytes;
    @Proto(4) bytes lzmaData = protoDefaultValue!bytes;
    @Proto(5) bytes OBSOLETEBzip2Data = protoDefaultValue!bytes;
}

struct BlobHeader
{
    @Proto(1) string type = protoDefaultValue!string;
    @Proto(2) bytes indexdata = protoDefaultValue!bytes;
    @Proto(3) int datasize = protoDefaultValue!int;
}