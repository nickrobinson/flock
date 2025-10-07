%module flock

%{
#include "flock.h"
%}

// Tell SWIG that MdnsDiscoverySession is an opaque pointer
// SWIG will create a SWIGTYPE_p_MdnsDiscoverySession wrapper for it
%nodefaultctor MdnsDiscoverySession;
%nodefaultdtor MdnsDiscoverySession;

// Map the C functions to cleaner Java/Kotlin method names
%rename(createSession) mdns_create_session;
%rename(startDiscovery) mdns_start_discovery;
%rename(receiveResponses) mdns_receive_responses;
%rename(getDeviceCount) mdns_get_device_count;
%rename(getDeviceName) mdns_get_device_name;
%rename(getDeviceIp) mdns_get_device_ip;
%rename(getDevicePort) mdns_get_device_port;
%rename(destroySession) mdns_destroy_session;
%rename(testSocket) mdns_test_socket;
%rename(testDiscovery) mdns_test_discovery;

// Tell SWIG to handle NULL pointers gracefully
%typemap(javacode) SWIGTYPE * %{
  // Helper to check if this is a null pointer
  protected boolean isNull() {
    return swigCPtr == 0;
  }
%}

// Include the header file for SWIG to parse
%include "flock.h"
