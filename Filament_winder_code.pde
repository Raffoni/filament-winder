// FORMAT: {r1: radius at station
//          len: distance along mandrel}
float[][] stations = {{100, 0}, {100, 100}, {50, 300}, {100, 500}, {100, 600}};
// FORMAT: {x, y, z}
ArrayList<float[]> strand_points = new ArrayList<float[]>();

// Machine variables
float wind_x = 0; // longitudinal position of head [mm]
float wind_z = 0; // radial position of head [mm]
float wind_theta = 0; // rotation of mandrel [rad]
float wind_gamma = 0; // rotation of head about radial axis [rad]
float curr_wind_angle = 0;

// Control
boolean DIR_FLAG = false; // 0 = left-to-right 1= right-to-left
int STATE = 0; //0=wind, 1=wind angle drop, 2=alignment
int WIND_NUMBER = 0;
float ALIGNMENT_TARGET = 0; //mm from end

// Parameters
float THETA_SPEED = 0.05; //nominal mandrel rotational velocity [rad/frame]
float WIND_ANGLE_DROP_SPEED = 0.05; // [rad/frame/frame]

float WIND_ANGLE; // Angle at which strand is layed onto mandrel [rad]
int NUM_WINDS;
int NUM_LAYERS;
float STRAND_WIDTH;
float ALIGNMENT_ZONE_WIDTH;
float WIND_ANGLE_DROP_ZONE_WIDTH;
float MANDREL_LENGTH;

int count = 0;

void setup() {
  size(600, 600, P3D);
  noStroke();
  loadData();
}

void draw() {
  background(0);
  
  lights();
  
  simpleWind();
  
  // Draw mandrel
  pushMatrix();
  translate(0, 100, -300);
  fill(255,255,255);
  for (int i = 1; i < stations.length; i++) {
    float len = stations[i][1] - stations[i-1][1];
    drawSegment(stations[i-1][0], stations[i][0], len, 20);
    translate(len, 0, 0);
  }
  popMatrix();
  
  // Draw machine head
  pushMatrix();
  translate(wind_x-10, 100-10, wind_z-100);
  fill(0,255,0);
  box(20, 20, 100);
  popMatrix();
  
  // Draw winded strand
  pushMatrix();
  stroke(255, 0, 0);
  translate(0, 100, -300);
  rotateX(wind_theta);
  drawStrand();
  noStroke();
  popMatrix();
  
  // Draw status text
  fill(255, 255, 255);
  pushMatrix();
  translate(20, height - 150,0);
  pushMatrix();
  text("AXIS POSITIONS", 0, 0);
  translate(0, 20, 0);
  text("X: "+wind_x, 20, 0);
  translate(0, 20, 0);
  text("Z: "+wind_z, 20, 0);
  translate(0, 20, 0);
  text("THETA: "+wind_theta, 20, 0);
  translate(0, 20, 0);
  text("GAMMA: "+wind_gamma, 20, 0);
  popMatrix();
  translate(200,0,0);
  text("OUTPUTS", 0, 0);
  translate(0, 20, 0);
  float curr_radius = getRadius(wind_x);
  text("Radius @ head: "+ curr_radius, 0, 0);
  popMatrix();
}

void simpleWind() {
  wind_theta += THETA_SPEED; // Mandrel rotates at constant speed
  
  float curr_radius = getRadius(wind_x);
  float curr_delta_radius = getRadiusSlope(wind_x);
  
   // Find beta angle, angle between axis of mandrel and current mandrel cone angle
  float beta = atan(curr_delta_radius);
  
  // Get alignment zone target
  if (!DIR_FLAG) {
    ALIGNMENT_TARGET = MANDREL_LENGTH - ALIGNMENT_ZONE_WIDTH + (ALIGNMENT_ZONE_WIDTH/NUM_WINDS)*WIND_NUMBER;
  } else {
    ALIGNMENT_TARGET = ALIGNMENT_ZONE_WIDTH - (ALIGNMENT_ZONE_WIDTH/NUM_WINDS)*WIND_NUMBER;
  }
  
  // state changer
  if ((abs(ALIGNMENT_TARGET - wind_x) < WIND_ANGLE_DROP_ZONE_WIDTH) && (STATE != 2)) {
    STATE = 1; 
  } else if (curr_wind_angle <= 0) {
    STATE = 3; 
  } else if (WIND_NUMBER > NUM_WINDS) {
    STATE = 4;
  } else {
    STATE = 0;
  }
  
  // Desired movement forwards should be the winding angle projected onto a plane parallel with the mandrel axis
  // mandrel has rotated theta rad
  // thus point under head has moved 2*pi*r*(theta/2*pi) = r*theta
  // thats the adjacent. tan(wind) = x/(r*theta)
  // so x = tan(wind)*r*theta
  // Project this x on the beta-angled plane (should become smaller with larger curr_delta)
  // cos(beta) = x_2/x so x_2 = cos(beta)*x
  switch (STATE) {
    case 0: //mid-wind
      if (!DIR_FLAG) { 
         wind_x += cos(beta)*tan(WIND_ANGLE)*curr_radius*THETA_SPEED;
        //wind_x += 1;
      } else {
        wind_x -= cos(beta)*tan(WIND_ANGLE)*curr_radius*THETA_SPEED;
        //wind_x -= 1;
      }
      curr_wind_angle = WIND_ANGLE;
      break;
    case 1: // wind angle drop zone
      if (!DIR_FLAG) { 
         wind_x += cos(beta)*tan(curr_wind_angle)*curr_radius*THETA_SPEED;
        //wind_x += 1;
      } else {
        wind_x -= cos(beta)*tan(curr_wind_angle)*curr_radius*THETA_SPEED;
        //wind_x -= 1;
      }
      curr_wind_angle -= WIND_ANGLE_DROP_SPEED;
      break;
    case 2: // wind angle increase zone
      if (!DIR_FLAG) { 
         wind_x += cos(beta)*tan(curr_wind_angle)*curr_radius*THETA_SPEED;
        //wind_x += 1;
      } else {
        wind_x -= cos(beta)*tan(curr_wind_angle)*curr_radius*THETA_SPEED;
        //wind_x -= 1;
      }
      curr_wind_angle += WIND_ANGLE_DROP_SPEED;
      break;
    case 3: // alignment zone
      // test. just instantly go the other way
      STATE = 2;
      curr_wind_angle = 0.01;
      DIR_FLAG = !DIR_FLAG;
      WIND_NUMBER++;
      break;
    case 4: // DONE
      break;
  }
  
  //Check if this puts head OB
  //if (wind_x >= stations[stations.length - 1][1]) { // OB+
  //  wind_x = stations[stations.length - 1][1];
  //  DIR_FLAG = !DIR_FLAG;
  //} else if (wind_x <= 0) { //OB-
  //  wind_x = 0;
  //  DIR_FLAG = !DIR_FLAG;
  //}
  
  // Add point to list
  float x = cos(wind_theta)*(curr_radius + 1);
  float y = wind_x;
  float z = sin(wind_theta)*(curr_radius + 1);
  
  float app[] = {y, z, x};
  
  strand_points.add(app);
  
  count++; //<>//
  
}

void drawStrand() {
  for(int i = 1; i < strand_points.size(); i++) {
    line(strand_points.get(i-1)[0], strand_points.get(i-1)[1], strand_points.get(i-1)[2], strand_points.get(i)[0], strand_points.get(i)[1], strand_points.get(i)[2]);
  }
}

float getRadius(float x) {
  // Find mandrel radius at head
  int i = 0;
  boolean ob_flag = false;
  float station_x = 0;
  while(station_x <=  x) {
    i++;
    if (i > stations.length - 1) {
      ob_flag = true;
      break;
    } else {
      station_x = stations[i][1];
    }
  }
  
  float curr_radius = 100;
  
  if (!ob_flag) {
    curr_radius = map(x, stations[i-1][1], stations[i][1], stations[i-1][0], stations[i][0]);
  }
  
  return curr_radius;
  
}

float getRadiusSlope(float x) {
  // Find mandrel radius at head
  int i = 0;
  boolean ob_flag = false;
  float station_x = 0;
  while(station_x <=  x) {
    i++;
    if (i > stations.length - 1) {
      ob_flag = true;
      break;
    } else {
      station_x = stations[i][1];
    }
  }
  
  float curr_delta_radius = 0;
  
  if (!ob_flag) {
    curr_delta_radius = (stations[i][0] - stations[i-1][0])/(stations[i][1] - stations[i-1][1]);
  }
  
  return curr_delta_radius;
}

void drawSegment(float r1, float r2, float len, int sides) {
  float angle = 0;
  float angleIncrement = TWO_PI/sides;
  beginShape(QUAD_STRIP);
  for(int i = 0; i < sides + 1; ++i) {
    vertex(0, r1*cos(angle), r1*sin(angle));
    vertex(len, r2*cos(angle), r2*sin(angle));
    angle += angleIncrement;
  }
  endShape();
}

void loadData() {
  String[] lines = loadStrings("data.txt");
  WIND_ANGLE = float(lines[0]);
  NUM_WINDS = int(lines[1]);
  NUM_LAYERS = int(lines[2]);
  STRAND_WIDTH = float(lines[3]);
  println("loaded data");
  println("wind angle:\t\t"+WIND_ANGLE);
  println("# winds:\t\t\t"+NUM_WINDS);
  println("# layers:\t\t"+NUM_LAYERS);
  println("strand width:\t\t"+STRAND_WIDTH);
  
  curr_wind_angle = WIND_ANGLE;
  
  MANDREL_LENGTH = stations[stations.length - 1][1];
  
  WIND_ANGLE_DROP_ZONE_WIDTH = tan(WIND_ANGLE)*100*((WIND_ANGLE/WIND_ANGLE_DROP_SPEED)*THETA_SPEED);
  ALIGNMENT_ZONE_WIDTH = STRAND_WIDTH * NUM_WINDS;
  
  println(ALIGNMENT_ZONE_WIDTH+" + "+WIND_ANGLE_DROP_ZONE_WIDTH+"mm of each end of the mandrel will be used for non-structural alignment zone");
  
}
