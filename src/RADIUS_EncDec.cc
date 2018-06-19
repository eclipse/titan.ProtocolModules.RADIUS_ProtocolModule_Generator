/******************************************************************************
* Copyright (c) 2008, 2015  Ericsson AB
* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v1.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-v10.html
*
* Contributors:
* Timea Moder
* Endre Kulcsar
* Gabor Szalai
* Janos Kovesdi
* Kulcsár Endre
* Zoltan Medve
* Tamas Korosi
******************************************************************************/

//
//  File:               RADIUS_EncDec.cc
//  Description:        Encoder/Decoder and external functions for RPMG
//  Rev:                R14A
//  Prodnr:             CNL 113 600
//  Reference:          RFC 2865(RADIUS), 2866(RADIUS Accounting),        
//                       
//                      
//

#include "RADIUS_Types.hh"

#include <openssl/md5.h>

namespace RADIUS__Types{


// calculates 16 bit MD5 message digest
OCTETSTRING f__calc__MD5(const OCTETSTRING& input)
   {  
      unsigned char output[16];     
      MD5(input,(size_t) input.lengthof(),output);  //error check!   
      OCTETSTRING MD5_Value(16,output);  
            
      return MD5_Value;   
   }
   
// copied from Radius Test Port  ( secret CHARSTRING -> OCTETSTRING
OCTETSTRING f__crypt__password (const OCTETSTRING& P, const OCTETSTRING& req__auth, const OCTETSTRING& salt,const BOOLEAN& decrypt, const CHARSTRING& secret) {

  const unsigned char* P_p = (const unsigned char*)P;
  int P_num = P.lengthof() / 16;
  
  if (P.lengthof() % 16 != 0)
    TTCN_warning("Length of P should be multiple of 16");
  
  unsigned char b[16];

  const OCTETSTRING& SRA = char2oct(secret) + req__auth + salt;

  TTCN_Logger::begin_event(TTCN_DEBUG);
  TTCN_Logger::log_event("SRA: ");
  SRA.log();
  TTCN_Logger::end_event();
  
  MD5((const unsigned char*)SRA, SRA.lengthof(), b);
  
  unsigned char* C = new unsigned char [P_num * 16]; // output buffer
  
  for (int j = 0; j < 16; j++) {
    C[j] = P_p[j] ^ b[j];
  }
  
  unsigned int S_len = secret.lengthof();
  
  unsigned char* Sc = new unsigned char[S_len + 16];
  memcpy(Sc, (const unsigned char*)(const char*)secret, S_len);
  
  for (int i = 1; i < P_num; i++) {
    if (decrypt)
      memcpy(Sc + S_len, P_p + (i-1)*16, 16);
    else
      memcpy(Sc + S_len, C + (i-1)*16, 16);

    MD5(Sc, S_len + 16, b);
    for (int j = 0; j < 16; j++) {
      C[(i*16 + j)] = P_p[(i*16 +j)] ^ b[j];
    }
  }

  OCTETSTRING result = OCTETSTRING(P_num*16, (const unsigned char*)C);
  delete [] C;
  delete [] Sc; 

  TTCN_Logger::begin_event(TTCN_DEBUG);
  TTCN_Logger::log_event("Result of hashing: ");
  result.log();
  TTCN_Logger::end_event();

  return result;
  
} // crypt_password 

OCTETSTRING f__crypt__s__key(const OCTETSTRING& pl_s_key, const OCTETSTRING& pl_req_auth, const CHARSTRING& secret,const BOOLEAN& decrypt)
{
  if (decrypt)
  {
    const OCTETSTRING& salt = substr(pl_s_key, 0, 2);
    const OCTETSTRING& decrypted = f__crypt__password(substr(pl_s_key, 2, pl_s_key.lengthof() - 2),pl_req_auth, salt, true, secret);
    int key_len = *((const unsigned char*)decrypted); // first byte
    if (key_len > decrypted.lengthof() - 1) {
      TTCN_warning("Invalid key length in \'S\' key.");
      key_len = decrypted.lengthof() - 1;
    }
    const OCTETSTRING& key_length_and_key = substr(decrypted, 0, key_len + 1);
    OCTETSTRING result = salt + key_length_and_key;
    return result;
  } // decrypt_s_key 
  else
  { 
    if (pl_s_key.lengthof() < 3)
      TTCN_warning("string_val in \'S\' key must be at least 3 octets long.");
    const OCTETSTRING& salt = OCTETSTRING(2, (const unsigned char*)pl_s_key);
    const int key_len = *((const unsigned char*)pl_s_key + 2);
    const OCTETSTRING& key = OCTETSTRING(pl_s_key.lengthof() - 3, (const unsigned char*)pl_s_key + 3);
    int calc_key_len;
    if (key_len == 0)
      calc_key_len = key.lengthof();
    else {
      if (key_len != key.lengthof())
        TTCN_warning("Invalid key length in \'S\' key.");
      calc_key_len = key_len;
    }
    int padding_len = (16 - ((key.lengthof() + 1) % 16)) % 16; // +1 for the key length
    const OCTETSTRING& P = int2oct(calc_key_len, 1) + key + OCTETSTRING(padding_len, (const unsigned char*)"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0");
    OCTETSTRING result = salt + f__crypt__password(P, pl_req_auth, salt, false, secret);
    return result;
  }
}  // crypt_s_key

OCTETSTRING f__crypt__tunnel__password(const OCTETSTRING& pl_password, const OCTETSTRING& req_auth, const OCTETSTRING& salt, const CHARSTRING& secret,const BOOLEAN& decrypt) {
  if (decrypt)
  {
    const OCTETSTRING& plain = f__crypt__password(pl_password, req_auth, salt, true, secret);
    OCTETSTRING password;
    password = OCTETSTRING(plain.lengthof(), (const unsigned char*)plain + 1);
    return  password;
  }
  else
  {
    int data_len=pl_password.lengthof();
    // the following line pads P to be multiple of 16 octets
    const OCTETSTRING& P = int2oct(data_len, 1) + pl_password + OCTETSTRING(
      (16-((pl_password.lengthof() + 1) % 16)) % 16, (const unsigned char*)"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0");
    return f__crypt__password(P, req_auth, salt, false, secret);
  }
} // encrypt_tunnel_password

   
OCTETSTRING f__RADIUS__Enc(const PDU__RADIUS& pdu)
{
  PDU__RADIUS* par=NULL;
    
  TTCN_Buffer buf;
  TTCN_EncDec::error_type_t err;
  buf.clear();
  TTCN_EncDec::clear_error();
  TTCN_EncDec::set_error_behavior(TTCN_EncDec::ET_ALL, TTCN_EncDec::EB_WARNING);
  if(par)
    par->encode(PDU__RADIUS_descr_, buf, TTCN_EncDec::CT_RAW);
  else 
    pdu.encode(PDU__RADIUS_descr_, buf, TTCN_EncDec::CT_RAW);
  err = TTCN_EncDec::get_last_error_type();
  if(err != TTCN_EncDec::ET_NONE)
    TTCN_warning("Encoding error: %s\n", TTCN_EncDec::get_error_str());
  delete par;
  return OCTETSTRING(buf.get_len(), buf.get_data());
}

PDU__RADIUS f__RADIUS__Dec(const OCTETSTRING& stream) 
{
  PDU__RADIUS pdu;
  TTCN_Buffer buf;
  TTCN_EncDec::error_type_t err;
  TTCN_EncDec::clear_error();
  buf.clear();
  buf.put_os(stream);
  TTCN_EncDec::set_error_behavior(TTCN_EncDec::ET_ALL, TTCN_EncDec::EB_WARNING);
  pdu.decode(PDU__RADIUS_descr_, buf, TTCN_EncDec::CT_RAW);
  err = TTCN_EncDec::get_last_error_type();
  if(err != TTCN_EncDec::ET_NONE)
    TTCN_warning("Decoding error: %s\n", TTCN_EncDec::get_error_str());
  return pdu;
}

BOOLEAN f__salt__value(vendor__specific__value&  pdu, const OCTETSTRING&  req_auth, const CHARSTRING&  secret, const BOOLEAN& decrypt){
  OCTETSTRING salt;
  OCTETSTRING key;
  switch(pdu.get_selection()){
    case vendor__specific__value::ALT_unsalted__integer:
    {
      salt = pdu.unsalted__integer().salt();
      key = int2oct(pdu.unsalted__integer().unsalted__value(),4); 
      break;
    }
    case vendor__specific__value::ALT_unsalted__text:
    {
      salt = pdu.unsalted__text().salt();
      key = char2oct(pdu.unsalted__text().unsalted__value()); 
      break;
    }
    case vendor__specific__value::ALT_unsalted__string:
    {
      salt = pdu.unsalted__string().salt();
      key = pdu.unsalted__string().unsalted__value(); 
      break;
    }
    case vendor__specific__value::ALT_string__val:
    {
      salt =OCTETSTRING(0, (const unsigned char*)"\0");
      key = pdu.string__val(); 
      break;
    }
    default:
      return false;
  }
  OCTETSTRING string_val;
  if(decrypt){
	string_val = f__crypt__password (key,req_auth , salt, decrypt, secret);
    int key_len = *((const unsigned char*)string_val); // first byte

    if (key_len > string_val.lengthof() - 1) {
      TTCN_warning("Invalid key length");
      key_len = string_val.lengthof() - 1;
    }
    string_val = substr(string_val, 1, key_len);
  } else {
	  const int key_len = key.lengthof();
	  int padding_len = (16 - ((key_len + 1) % 16)) % 16; // +1 for the key length
	  const OCTETSTRING& P = int2oct(key.lengthof(), 1) + key + OCTETSTRING(padding_len, (const unsigned char*)"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0");
	  string_val = f__crypt__password (P,req_auth , salt, decrypt, secret);

  }
      
  if(salt.lengthof()!=0){
    pdu.unsalted__string().salt()=salt;
    pdu.unsalted__string().unsalted__value()=string_val;
  } else {
    pdu.string__val()=string_val;
  }
  return true;
}

bool f_convert_string_to_text(const OCTETSTRING& in, CHARSTRING& out){
  const unsigned char * key_ptr = (const unsigned char *)in;
  for (int i = 0; i<(in.lengthof());i++){
    if (key_ptr[i] & 0x80) {
      return false;
    }
  }
  out = oct2char(in);
  return true;
  
}

BOOLEAN f__convert__string__to__text(vendor__specific__value& pdu){
  CHARSTRING chr;
  switch(pdu.get_selection()){
    case vendor__specific__value::ALT_string__val:
    {
      if(f_convert_string_to_text( pdu.string__val(),chr)){
         pdu.text__val()=chr;
      } else { return false; }
      break;
    }
    case vendor__specific__value::ALT_unsalted__string:
    {
      if(f_convert_string_to_text( pdu.unsalted__string().unsalted__value(),chr)){
         OCTETSTRING salt=pdu.unsalted__string().salt();
         pdu.unsalted__text().unsalted__value()=chr;
         pdu.unsalted__text().salt()=salt;
      } else { return false; }
      break;
    }
    case vendor__specific__value::ALT_tagged__string:
    {
      if(f_convert_string_to_text( pdu.tagged__string().untagged__value(),chr)){
         OCTETSTRING tag=pdu.tagged__string().tag();
         pdu.tagged__text().untagged__value()=chr;
         pdu.tagged__text().tag()=tag;
      } else { return false; }
      break;
    }
    default:
      return false;
  }
  return true;
}


}
TTCN_Module RADIUS_EncDec("RADIUS_EncDec", __DATE__, __TIME__);
