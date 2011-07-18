// for nanode 0074
// MAC address is 00:04:A3:03:F1:F4

// test URL http://192.168.0.10/RESTbitlash/print(1+1)

#include "bitlash.h"
#include "EtherShield.h"

// please modify the following three lines. mac and ip have to be unique
// in your local area network. You can not have the same numbers in
// two devices:
static uint8_t mymac[6] = { 0x00,0x04,0xA3,0x03,0xF1,0xF4}; 
static uint8_t myip[4] = { 192,168,0,10 };

#define MYWWWPORT 80
#define BUFFER_SIZE 550
static uint8_t buf[BUFFER_SIZE+1];

// The ethernet shield
EtherShield es=EtherShield();

//JSON gubbins
char jsonOut[50];

/********* **********/
uint16_t http200ok(void)
{
  return(es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nPragma: no-cache\r\n\r\n")));
}

/********* no sexy 404 page here **********/
uint16_t http404(void)
{
  return(es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 401 Unauthorized\r\nContent-Type: text/html\r\n\r\n<h1>401 Unauthorized</h1>")));
}

/********* heres where we do the messy bit? **********/
#define CMDBUF 250
int16_t sendCommand(char *str)
{
  int8_t r=-1;
  int8_t i = 0;
  char clientline[CMDBUF];
  int index = 0;
  int httpOutput = 0;
  
  Serial.print("monkey2");
  
  char ch = str[index];
  while( ch != ' ' && index < CMDBUF) {
    clientline[index] = ch;
    index++;
    ch = str[index];
  }
  // insert a null char at the end to make this a 'c string'
  clientline[index] = '\0';

  // convert clientline into a proper
  // string for further processing
  String urlString = String(clientline);
  
  //if url has /RESTbitlash/
  int restBitlashIndex = urlString.indexOf('/RESTbitlash/');
  Serial.print("monkey3");
  //strip URL prefix so that we just have the command
  // the string /RESTbitlash/ is 13 chars long
  Serial.println(restBitlashIndex);
  restBitlashIndex = restBitlashIndex + 13;
  Serial.println(restBitlashIndex);
  String command = urlString.substring(restBitlashIndex, urlString.length());
  Serial.println("got the command: " + command);
  Serial.println();
  //send command to bitlash
  command.toCharArray(clientline, CMDBUF);
  Serial.println("converted to char array - sending the following:");
  Serial.println(clientline);
  doCommand(clientline);
  Serial.println("sent successfully");
  
  httpOutput=http200ok();

  httpOutput=es.ES_fill_tcp_data(buf,httpOutput,"<html><body><h1>Command succesfully received and executed<h1><br/>");
  //httpOutput=es.ES_fill_tcp_data(buf,httpOutput,jsonOut);
  httpOutput=es.ES_fill_tcp_data(buf,httpOutput,"</body></html>");
  // return
  return( httpOutput );
}

void serialHandler(byte b) {
  //output to json??
  Serial.print(b, BYTE);
  //sprintf( jsonOut, "{\"output\":\"%s\"}", (char) b );
}

/********* set us up the bomb **********/
void setup() {
  
  /****************************
   * initialise ethernet chip
   ****************************/
  // Initialise SPI interface
  es.ES_enc28j60SpiInit();

  // initialize enc28j60
  es.ES_enc28j60Init(mymac,8);

  // init the ethernet/ip layer:
  es.ES_init_ip_arp_udp_tcp(mymac,myip, MYWWWPORT);


  /*******************************************************
   * initialize bitlash and set primary serial port baud
   * print startup banner and run the startup macro
   *******************************************************/
  initBitlash(57600);
  setOutputHandler(&serialHandler);

  // you can execute commands here to set up initial state
  // bear in mind these execute after the startup macro
  // doCommand("print(1+1)");
}

/********* to infinity, and beyond! **********/
void loop() {
  runBitlash();

  // you can write to the bitlash console with
  //  doCharacter(char c)
        
  /********************
  * setup webserver
  ********************/
  uint16_t dat_p;

  while(1) {
    // read packet, handle ping and wait for a tcp packet:
   dat_p=es.ES_packetloop_icmp_tcp(buf,es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf));

    /* dat_p will be unequal to zero if there is a valid http get */
    if(dat_p==0){
      // no http request
      continue;
    }

    // tcp port 80 begin
    if (strncmp("GET ",(char *)&(buf[dat_p]),4)!=0) {
      // head, post and other methods:
      dat_p = http200ok();
      dat_p=es.ES_fill_tcp_data_p(buf,dat_p,PSTR("<h1>200 OK</h1>"));
      goto SENDTCP;
    }

    // just one web page in the "root directory" of the web server
    if (strncmp("/REST",(char *)&(buf[dat_p+4]),4)==0){
      // GET / Request
      Serial.print("monkey");
      dat_p = sendCommand((char *)&(buf[dat_p+4]));
      goto SENDTCP;
    }
    else {
      dat_p=http404();
      goto SENDTCP;
    }
    
SENDTCP:
    es.ES_www_server_reply(buf,dat_p); // send web page data
    // tcp port 80 end
  }
}
