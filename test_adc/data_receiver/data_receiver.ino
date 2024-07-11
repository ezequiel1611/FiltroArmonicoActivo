int port_value = 0;
int pin_values[8] = {0, 0, 0, 0, 0, 0, 0, 0};
int contador = 0;

void setup() {
  for (int i = 0; i < 8; i++){
    pinMode(3+i,INPUT);
  }
  pinMode(2, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(2), read_data, CHANGE);
  Serial.begin(115200);
}

void loop() {

}

void read_data() {
  if(contador == 0){
    for (int i = 0; i < 8; i++){
      pin_values[i] = digitalRead(3+i);
    }
    port_value = pin_values[0] + pin_values[1]*2 + pin_values[2]*4 + pin_values[3]*8 + pin_values[4]*16 + pin_values[5]*32 + pin_values[6]*64 + pin_values[7]*128;
    Serial.println(port_value);
    contador++;
    return;
  }
  else if(contador == 2) {
    contador=0;
    return;
  }
  else {
    contador++;
    return;
  }
}