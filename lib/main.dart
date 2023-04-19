import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xml/xml.dart' as xml;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Home());
  }
}

class Home extends StatefulWidget {
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool servicestatus = false;
  bool hasPermission = false;
  bool tracking = false;
  bool showSavedFiles = false;
  late LocationPermission permission;
  late Position position;
  Map<String, String> gpxList = {};
  String long = "",
      lat = "",
      ele = "",
      direction = "",
      wpt = "",
      formattedTimestamp = "",
      name = "",
      description = "";
  List<String> latitudes = [],
      longitudes = [],
      elevations = [],
      waypoints = [],
      timestamps = [];
  late StreamSubscription<Position> positionStream;

  @override
  void initState() {
    checkGps();
    super.initState();
  }

  Future checkGps() async {
    servicestatus = await Geolocator.isLocationServiceEnabled();
    if (servicestatus) {
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
        } else if (permission == LocationPermission.deniedForever) {
          print("'Location permissions are permanently denied");
        } else {
          hasPermission = true;
        }
      } else {
        hasPermission = true;
      }

      if (hasPermission) {
        setState(() {
          //refresh the UI
        });
      }
    } else {
      print("GPS Service is not enabled, turn on GPS location");
    }

    setState(() {
      //refresh the UI
    });
  }

  getLocation() async {
    tracking = true;
    showSavedFiles = false;
    latitudes = [];
    longitudes = [];
    elevations = [];
    waypoints = [];
    timestamps = [];
    LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        // distanceFilter: 1,
        // forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        // (Optional) Set foreground notification config to keep the app alive
        // when going to the background
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "GPX Recorder app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          enableWakeLock: true,
        ));

    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      long = position.longitude.toString();
      lat = position.latitude.toString();
      ele = position.altitude.toString();
      DateTime timestamp = position.timestamp!.toLocal();
      formattedTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);

      print(formattedTimestamp);
      print(long);
      print(lat);
      print(ele);
      print(wpt);

      longitudes.add(long);
      latitudes.add(lat);
      elevations.add(ele);
      waypoints.add(wpt);
      timestamps.add(formattedTimestamp);

      wpt = "";

      setState(() {
        //refresh UI on update
      });
    });
  }

  stopLocation() {
    tracking = false;
    positionStream.cancel();
    setState(() {
      //refresh UI on update
    });
  }

  void createGPXFile() {
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0"');
    builder.element('gpx', nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'GPX Recorder');

      builder.element('metadata', nest: () {
        builder.element('name', nest: 'My GPX Recorder File');
        builder.element('desc', nest: 'A GPX file created using GPX Recorder');
      });

      builder.element('trk', nest: () {
        builder.element('name', nest: 'My Track');

        builder.element('trkseg', nest: () {
          for (int i = 0; i < latitudes.length; i++) {
            if (waypoints[i] != "") {
              builder.element('wpt', nest: () {
                builder.attribute('lat', latitudes[i]);
                builder.attribute('lon', longitudes[i]);

                builder.element('name', nest: waypoints[i]);
              });
            }

            builder.element('trkpt', nest: () {
              builder.attribute('lat', latitudes[i]);
              builder.attribute('lon', longitudes[i]);

              builder.element('ele', nest: elevations[i]);
              builder.element('time', nest: timestamps[i]);
            });
          }
        });
      });
    });

    print(waypoints);

    final gpx = builder.buildDocument();
    final gpxString =
        xml.XmlDocument.parse(gpx.toString()).toXmlString(pretty: true);

    saveFile('${timestamps[0].substring(0, 16).replaceAll(' ', '_')}.gpx',
        gpxString);
  }

  void getGpxList() {
    showSavedFiles = !showSavedFiles;
    getApplicationDocumentsDirectory().then((directory) {
      final fileList = directory
          .listSync()
          .where((file) => file.path.endsWith('.gpx'))
          .toList();
      fileList.forEach((element) {
        if (element is File) {
          File file = element;
          file.readAsString().then((content) {
            gpxList[file.path.split('/').last] = file.path;
            setState(() {
              //refresh UI on update
            });
          });
        }
      });
    });
  }

  void deleteGpxFile(String filePath) {
    File file = File(filePath);
    file.delete().then((value) {
      setState(() {
        gpxList.remove(file.path.split('/').last);
      });
    });
  }

  void addPointOfInterest() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Point of Interest'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) {
                  name = value;
                },
                decoration: InputDecoration(
                  hintText: 'Name',
                ),
              ),
              TextField(
                onChanged: (value) {
                  description = value;
                },
                decoration: InputDecoration(
                  hintText: 'Description',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                wpt = name;
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> saveFile(String filename, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);

    Fluttertoast.showToast(msg: 'File saved...');

    getGpxList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GPX Recorder"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      hasPermission
                          ? "GPS has permission."
                          : "GPS does not have permission.",
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      servicestatus ? " GPS is enabled." : " GPS is disabled.",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (tracking)
              Text(
                formattedTimestamp,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 10),
            if (tracking)
              Text(
                "Longitude: $long",
                style: const TextStyle(fontSize: 22),
              ),
            const SizedBox(height: 10),
            if (tracking)
              Text(
                "Latitude: $lat",
                style: const TextStyle(fontSize: 22),
              ),
            const SizedBox(height: 10),
            if (tracking)
              Text(
                "Elevation: $ele",
                style: const TextStyle(fontSize: 22),
              ),
            const SizedBox(height: 20),
            if (!tracking)
              ElevatedButton(
                style: ElevatedButton.styleFrom(primary: Colors.redAccent),
                onPressed: () => getLocation(),
                child: const Text('Start Recording'),
              ),
            if (tracking)
              ElevatedButton(
                style: ElevatedButton.styleFrom(primary: Colors.redAccent),
                onPressed: () {
                  stopLocation();
                  createGPXFile();
                },
                child: const Text('Stop Recording'),
              ),
            const SizedBox(height: 10),
            if (tracking)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    primary: Color.fromARGB(255, 5, 107, 58)),
                onPressed: () => addPointOfInterest(),
                child: const Text('Add Point of Interest'),
              ),
            const SizedBox(height: 10),
            if (!tracking)
              ElevatedButton(
                style: ElevatedButton.styleFrom(primary: Colors.blueAccent),
                onPressed: () => getGpxList(),
                child: const Text('View Saved GPXs'),
              ),
            const SizedBox(height: 10),
            if (!tracking && showSavedFiles && gpxList.isNotEmpty)
              Expanded(
                child: SizedBox(
                  height: 300, // set the height to a fixed value
                  child: ListView.builder(
                    itemCount: gpxList.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          gpxList.keys.toList()[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                // Do something when the first button is pressed.
                              },
                              child: const Text('Upload'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () =>
                                  deleteGpxFile(gpxList.values.toList()[index]),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        )),
      ),
    );
  }
}
