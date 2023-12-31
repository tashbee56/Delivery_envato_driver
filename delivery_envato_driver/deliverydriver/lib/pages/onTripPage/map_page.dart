import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:deliverydriver/functions/functions.dart';
import 'package:deliverydriver/functions/geohash.dart';
import 'package:deliverydriver/functions/notifications.dart';
import 'package:deliverydriver/pages/NavigatorPages/notification.dart';
import 'package:deliverydriver/pages/chatPage/chat_page.dart';
import 'package:deliverydriver/pages/loadingPage/loadingpage.dart';
import 'package:deliverydriver/pages/login/signupmethod.dart';
import 'package:deliverydriver/pages/onTripPage/digitalsignature.dart';
import 'package:deliverydriver/pages/onTripPage/invoice.dart';
import 'package:deliverydriver/pages/loadingPage/loading.dart';
import 'package:deliverydriver/pages/login/login.dart';
import 'package:deliverydriver/pages/navDrawer/nav_drawer.dart';
import 'package:deliverydriver/pages/noInternet/nointernet.dart';
import 'package:deliverydriver/pages/vehicleInformations/docs_onprocess.dart';
import 'package:deliverydriver/styles/styles.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'package:deliverydriver/translation/translation.dart';
import 'package:deliverydriver/widgets/widgets.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:vector_math/vector_math.dart' as vector;
import 'package:http/http.dart' as http;

class Maps extends StatefulWidget {
  const Maps({Key? key}) : super(key: key);

  @override
  State<Maps> createState() => _MapsState();
}

dynamic _center = const LatLng(41.4219057, -102.0840772);
dynamic center;
bool locationAllowed = false;

List<Marker> myMarkers = [];
// Set<Marker> _markers = {};
Set<Circle> circles = {};
bool polylineGot = false;
bool serviceEnabled = false;
dynamic _timer;
String cancelReasonText = '';
bool notifyCompleted = false;
bool logout = false;
bool getStartOtp = false;
String driverOtp = '';
dynamic shipLoadImage;
dynamic shipUnloadImage;
bool unloadImage = false;
bool deleteAccount = false;
var iconDropKeys = {};
GlobalKey iconKey = GlobalKey();
GlobalKey iconDropKey = GlobalKey();

class _MapsState extends State<Maps>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List driverData = [];
  bool sosLoaded = false;
  bool cancelRequest = false;
  late bool serviceEnabled;
  late geolocator.LocationPermission permission;
  Location location = Location();
  String state = '';
  dynamic _controller;
  Animation<double>? _animation;
  dynamic animationController;
  String _cancellingError = '';
  double mapPadding = 0.0;

  String _cancelReason = '';
  bool _locationDenied = false;
  int gettingPerm = 0;
  bool _errorOtp = false;
  String beforeImageUploadError = '';
  String afterImageUploadError = '';
  dynamic loc;
  String _otp1 = '';
  String _otp2 = '';
  String _otp3 = '';
  String _otp4 = '';
  bool showSos = false;
  bool _showWaitingInfo = false;
  bool _isLoading = false;
  bool _reqCancelled = false;
  dynamic pinLocationIcon;
  dynamic pinLocationIcon2;
  dynamic userLocationIcon;
  bool makeOnline = false;
  bool contactus = false;
  dynamic onrideicon;
  dynamic offlineicon;
  dynamic onlineicon;
  dynamic onridebikeicon;
  dynamic offlinebikeicon;
  dynamic onlinebikeicon;
  bool _tripOpenMap = false;
  bool show = true;
  int filtericon = 0;
  bool _isDarkTheme = false;

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _controller = controller;
      _controller?.setMapStyle(mapStyle);
    });
  }

  final _mapMarkerSC = StreamController<List<Marker>>();
  StreamSink<List<Marker>> get _mapMarkerSink => _mapMarkerSC.sink;
  Stream<List<Marker>> get mapMarkerStream => _mapMarkerSC.stream;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    polylineGot = false;
    _isDarkTheme = isDarkTheme;
    getLocs();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _controller!.setMapStyle(mapStyle);
        valueNotifierHome.incrementNotifier();
      }
      isBackground = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      isBackground = true;
    }
  }

  @override
  void dispose() {
    if (_timer != null) {
      _timer?.cancel();
    }
    _controller?.dispose();
    _controller = null;
    if (animationController != null) {
      animationController?.dispose();
    }
    super.dispose();
  }

//navigate
  navigate() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const DigitalSignature()));
  }

  reqCancel() {
    _reqCancelled = true;

    Future.delayed(const Duration(seconds: 2), () {
      _reqCancelled = false;
      userReject = false;
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  navigateLogout() {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignupMethod()),
        (route) => false);
  }

//getting permission and current location
  getLocs() async {
    unloadImage = false;
    afterImageUploadError = '';
    beforeImageUploadError = '';
    shipLoadImage = null;
    shipUnloadImage = null;
    permission = await geolocator.GeolocatorPlatform.instance.checkPermission();
    serviceEnabled =
        await geolocator.GeolocatorPlatform.instance.isLocationServiceEnabled();
    myMarkers.clear();
    if (permission == geolocator.LocationPermission.denied ||
        permission == geolocator.LocationPermission.deniedForever ||
        serviceEnabled == false) {
      gettingPerm++;
      if (gettingPerm > 1) {
        locationAllowed = false;
        if (userDetails['active'] == true) {
          var val = await driverStatus();
          if (val == 'logout') {
            navigateLogout();
          }
        }
        state = '3';
      } else {
        state = '2';
      }
      setState(() {
        _isLoading = false;
      });
    } else if (permission == geolocator.LocationPermission.whileInUse ||
        permission == geolocator.LocationPermission.always) {
      final Uint8List markerIcon =
          await getBytesFromAsset('assets/images/vehicle-marker.png', 40);
      final Uint8List markerIcon2 =
          await getBytesFromAsset('assets/images/bike.png', 40);
      if (userDetails['role'] == 'owner') {
        final Uint8List onrideicon1 =
            await getBytesFromAsset('assets/images/onboardicon.png', 40);
        final Uint8List offlineicon1 =
            await getBytesFromAsset('assets/images/offlineicon.png', 40);
        final Uint8List onlineicon1 =
            await getBytesFromAsset('assets/images/onlineicon.png', 40);
        final Uint8List onlinebikeicon1 =
            await getBytesFromAsset('assets/images/bike_online.png', 40);
        final Uint8List onridebikeicon1 =
            await getBytesFromAsset('assets/images/bike_onride.png', 40);
        final Uint8List offlinebikeicon1 =
            await getBytesFromAsset('assets/images/bike.png', 40);
        onrideicon = BitmapDescriptor.fromBytes(onrideicon1);
        offlineicon = BitmapDescriptor.fromBytes(offlineicon1);
        onlineicon = BitmapDescriptor.fromBytes(onlineicon1);
        onridebikeicon = BitmapDescriptor.fromBytes(onridebikeicon1);
        offlinebikeicon = BitmapDescriptor.fromBytes(offlinebikeicon1);
        onlinebikeicon = BitmapDescriptor.fromBytes(onlinebikeicon1);
      }
      if (center == null) {
        var locs = await geolocator.Geolocator.getLastKnownPosition();
        if (locs != null) {
          center = LatLng(locs.latitude, locs.longitude);
          heading = locs.heading;
        } else {
          loc = await geolocator.Geolocator.getCurrentPosition(
              desiredAccuracy: geolocator.LocationAccuracy.low);
          center = LatLng(double.parse(loc.latitude.toString()),
              double.parse(loc.longitude.toString()));
          heading = loc.heading;
        }
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(center, 14.0));
      }
      setState(() {
        pinLocationIcon = BitmapDescriptor.fromBytes(markerIcon);
        pinLocationIcon2 = BitmapDescriptor.fromBytes(markerIcon2);

        if (myMarkers.isEmpty && userDetails['role'] != 'owner') {
          myMarkers = [
            Marker(
                markerId: const MarkerId('1'),
                rotation: heading,
                position: center,
                icon: (userDetails['vehicle_type_icon_for'] == 'motor_bike')
                    ? pinLocationIcon2
                    : pinLocationIcon,
                anchor: const Offset(0.5, 0.5))
          ];
        }
      });
      if (makeOnline == true && userDetails['active'] == false) {
        var val = await driverStatus();
        if (val == 'logout') {
          navigateLogout();
        }
      }
      makeOnline = false;
      setState(() {
        state = '3';
        locationAllowed = true;
        _isLoading = false;
      });
    }
  }

  getCustomIcon(GlobalKey iconKeys) async {
    capturePng(GlobalKey iconKeys) async {
      dynamic pngBytes;

      try {
        RenderRepaintBoundary boundary = iconKeys.currentContext!
            .findRenderObject() as RenderRepaintBoundary;
        ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        pngBytes = byteData!.buffer.asUint8List();
        // return pngBytes;
      } catch (e) {
        debugPrint('errors $e');
      }
      return pngBytes;
    }

    Uint8List imageData = await capturePng(iconKeys);

    return BitmapDescriptor.fromBytes(imageData);
  }

  addDropMarker() async {
    // polyList.clear();
    if (tripStops.isNotEmpty) {
      for (var i = 0; i < tripStops.length; i++) {
        var testIcon = await getCustomIcon(iconDropKeys[i]);
        // ignore: unnecessary_null_comparison
        if (testIcon != null) {
          myMarkers.add(Marker(
              markerId: MarkerId((i + 3).toString()),
              icon: testIcon,
              position:
                  LatLng(tripStops[i]['latitude'], tripStops[i]['longitude'])));
        }
        // polyList
        //     .add(LatLng(tripStops[i]['latitude'], tripStops[i]['longitude']));

        // if (i == tripStops.length - 1) {
        //   polyline.add(
        //     Polyline(
        //         polylineId: const PolylineId('1'),
        //         color: buttonColor,
        //         visible: true,
        //         width: 2,
        //         points: polyList),
        //   );
        // }
      }
    } else {
      var testIcon = await getCustomIcon(iconDropKey);
      // ignore: unnecessary_null_comparison
      if (testIcon != null) {
        myMarkers.add(Marker(
            markerId: const MarkerId('3'),
            icon: testIcon,
            position: LatLng(driverReq['drop_lat'], driverReq['drop_lng'])));
      }
    }
    getLatLngBounds();
    setState(() {});
  }

  addMarker() async {
    if (driverReq.isNotEmpty) {
      var testIcon = await getCustomIcon(iconKey);
      // ignore: unnecessary_null_comparison
      if (testIcon != null) {
        setState(() {
          myMarkers.add(Marker(
              markerId: const MarkerId('2'),
              icon: testIcon,
              position: LatLng(driverReq['pick_lat'], driverReq['pick_lng'])));
        });
      }
    }
    if (driverReq['drop_address'] != null) {
      addDropMarker();
      if (polyline.isEmpty && polylineGot == false) {
        polylineGot = true;
        getPolylines();
      }
    } else {
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(driverReq['pick_lat'], driverReq['pick_lng']), 11.0));
    }
  }

  getLocationPermission() async {
    if (serviceEnabled == false) {
      await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.low);
    }
    if (await geolocator.GeolocatorPlatform.instance
        .isLocationServiceEnabled()) {
      if (permission == geolocator.LocationPermission.denied ||
          permission == geolocator.LocationPermission.deniedForever) {
        //  var _lpermission = await perm.Permission.location.shouldShowRequestRationale;
        //  print(_lpermission);
        if (permission != geolocator.LocationPermission.deniedForever &&
            await geolocator.GeolocatorPlatform.instance
                .isLocationServiceEnabled()) {
          if (platform == TargetPlatform.android) {
            await perm.Permission.location.request();
            await perm.Permission.locationAlways.request();
          } else {
            await [perm.Permission.location].request();
          }
        }
      }
    }
    setState(() {
      _isLoading = true;
    });
    getLocs();
  }

  getLatLngBounds() {
    LatLngBounds bound;
    if (driverReq['pick_lat'] > driverReq['drop_lat'] &&
        driverReq['pick_lng'] > driverReq['drop_lng']) {
      bound = LatLngBounds(
          southwest: LatLng(driverReq['drop_lat'], driverReq['drop_lng']),
          northeast: LatLng(driverReq['pick_lat'], driverReq['pick_lng']));
    } else if (driverReq['pick_lng'] > driverReq['drop_lng']) {
      bound = LatLngBounds(
          southwest: LatLng(driverReq['pick_lat'], driverReq['drop_lng']),
          northeast: LatLng(driverReq['drop_lat'], driverReq['pick_lng']));
    } else if (driverReq['pick_lat'] > driverReq['drop_lat']) {
      bound = LatLngBounds(
          southwest: LatLng(driverReq['drop_lat'], driverReq['pick_lng']),
          northeast: LatLng(driverReq['pick_lat'], driverReq['drop_lng']));
    } else {
      bound = LatLngBounds(
          southwest: LatLng(driverReq['pick_lat'], driverReq['pick_lng']),
          northeast: LatLng(driverReq['drop_lat'], driverReq['drop_lng']));
    }

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bound, 50);
    _controller?.animateCamera(cameraUpdate);
  }

  int _bottom = 0;

  GeoHasher geo = GeoHasher();
  String _permission = '';

  @override
  Widget build(BuildContext context) {
    //get camera permission
    getCameraPermission() async {
      var status = await perm.Permission.camera.status;
      if (status != perm.PermissionStatus.granted) {
        status = await perm.Permission.camera.request();
      }
      return status;
    }

    ImagePicker picker = ImagePicker();
    //pick image from camera
    pickImageFromCamera(id) async {
      var permission = await getCameraPermission();
      if (permission == perm.PermissionStatus.granted) {
        final pickedFile = await picker.pickImage(
            source: ImageSource.camera, imageQuality: 50);
        if (pickedFile != null) {
          setState(() {
            if (id == 1) {
              shipLoadImage = pickedFile.path;
            } else {
              shipUnloadImage = pickedFile.path;
            }
            // _pickImage = false;
          });
        }
      } else {
        setState(() {
          _permission = 'noCamera';
        });
      }
    }

    var media = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        platforms.invokeMethod('pipmode');
        return false;
      },
      child: Material(
        child: ValueListenableBuilder(
            valueListenable: valueNotifierHome.value,
            builder: (context, value, child) {
              if (_isDarkTheme != isDarkTheme && _controller != null) {
                _controller!.setMapStyle(mapStyle);
                _isDarkTheme = isDarkTheme;
              }
              if (isGeneral == true) {
                isGeneral = false;
                if (lastNotification != latestNotification) {
                  lastNotification = latestNotification;
                  pref.setString('lastNotification', latestNotification);
                  latestNotification = '';
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const NotificationPage()));
                  });
                }
              }
              if (myMarkers
                  .where((element) => element.markerId == const MarkerId('1'))
                  .isNotEmpty) {
                if (userDetails['vehicle_type_icon_for'] == 'truck' &&
                    myMarkers
                            .firstWhere((element) =>
                                element.markerId == const MarkerId('1'))
                            .icon ==
                        pinLocationIcon2) {
                  myMarkers.removeWhere(
                      (element) => element.markerId == const MarkerId('1'));
                } else if (userDetails['vehicle_type_icon_for'] != 'truck' &&
                    myMarkers
                            .firstWhere((element) =>
                                element.markerId == const MarkerId('1'))
                            .icon ==
                        pinLocationIcon) {
                  myMarkers.removeWhere(
                      (element) => element.markerId == const MarkerId('1'));
                }
              }
              if (userDetailsError == true) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoadingPage()),
                      (route) => false);
                });
              }
              if (myMarkers
                      .where(
                          (element) => element.markerId == const MarkerId('1'))
                      .isNotEmpty &&
                  pinLocationIcon != null &&
                  center != null &&
                  _controller != null) {
                var dist = calculateDistance(
                    myMarkers
                        .firstWhere((element) =>
                            element.markerId == const MarkerId('1'))
                        .position
                        .latitude,
                    myMarkers
                        .firstWhere((element) =>
                            element.markerId == const MarkerId('1'))
                        .position
                        .longitude,
                    center.latitude,
                    center.longitude);
                if (dist > 100 &&
                    animationController == null &&
                    _controller != null) {
                  animationController = AnimationController(
                    duration: const Duration(
                        milliseconds: 1500), //Animation duration of marker

                    vsync: this, //From the widget
                  );
                  animateCar(
                      myMarkers
                          .firstWhere((element) =>
                              element.markerId == const MarkerId('1'))
                          .position
                          .latitude,
                      myMarkers
                          .firstWhere((element) =>
                              element.markerId == const MarkerId('1'))
                          .position
                          .longitude,
                      center.latitude,
                      center.longitude,
                      _mapMarkerSink,
                      this,
                      _controller,
                      '1',
                      (userDetails['vehicle_type_icon_for'] == 'motor_bike')
                          ? pinLocationIcon2
                          : pinLocationIcon,
                      '',
                      '');
                }
              } else if (myMarkers
                      .where(
                          (element) => element.markerId == const MarkerId('1'))
                      .isEmpty &&
                  pinLocationIcon != null &&
                  center != null &&
                  userDetails['role'] != 'owner') {
                myMarkers.add(Marker(
                    markerId: const MarkerId('1'),
                    rotation: heading,
                    position: center,
                    icon: (userDetails['vehicle_type_icon_for'] == 'motor_bike')
                        ? pinLocationIcon2
                        : pinLocationIcon,
                    anchor: const Offset(0.5, 0.5)));
              }
              if (driverReq.isNotEmpty) {
                if (_controller != null) {
                  mapPadding = media.width * 1;
                }
                if (driverReq['is_completed'] != 1) {
                  if (myMarkers
                      .where(
                          (element) => element.markerId == const MarkerId('2'))
                      .isEmpty) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      addMarker();
                    });
                  }
                } else if (driverReq['is_completed'] == 1 &&
                    driverReq['requestBill'] != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Invoice()),
                        (route) => false);
                  });
                  // _pickAnimateDone = false;
                  myMarkers.removeWhere(
                      (element) => element.markerId != const MarkerId('1'));
                  // myMarkers.removeWhere(
                  //     (element) => element.markerId == const MarkerId('3'));
                  polyline.clear();
                  polylineGot = false;
                }
              } else {
                mapPadding = 0;
                if (myMarkers
                    .where((element) => element.markerId != const MarkerId('1'))
                    .isNotEmpty) {
                  myMarkers.removeWhere(
                      (element) => element.markerId != const MarkerId('1'));
                  polyline.clear();
                  if (userReject == true) {
                    reqCancel();
                  }
                  polylineGot = false;
                  // _pickAnimateDone = false;
                }
              }
              if (userDetails['approve'] == false && driverReq.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DocsProcess()),
                      (route) => false);
                });
              }
              if (package == null) {
                checkVersion();
              }
              return Directionality(
                textDirection: (languageDirection == 'rtl')
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: Scaffold(
                  drawer: const NavDrawer(),
                  body: StreamBuilder(
                      stream: userDetails['role'] == 'owner'
                          ? FirebaseDatabase.instance
                              .ref('drivers')
                              .orderByChild('ownerid')
                              .equalTo(userDetails['id'].toString())
                              .onValue
                          : null,
                      builder: (context, AsyncSnapshot<DatabaseEvent> event) {
                        if (event.hasData) {
                          driverData.clear();
                          for (var element in event.data!.snapshot.children) {
                            driverData.add(element.value);
                          }
                          for (var element in driverData) {
                            if (element['l'] != null &&
                                element['is_deleted'] != 1) {
                              if (userDetails['role'] == 'owner') {
                                if (userDetails['role'] == 'owner' &&
                                    offlineicon != null &&
                                    onlineicon != null &&
                                    onrideicon != null &&
                                    filtericon == 0) {
                                  if (myMarkers
                                      .where((e) => e.markerId
                                          .toString()
                                          .contains('car${element['id']}'))
                                      .isEmpty) {
                                    myMarkers.add(Marker(
                                      markerId: MarkerId('car${element['id']}'),
                                      rotation: double.parse(
                                          element['bearing'].toString()),
                                      position: LatLng(
                                          element['l'][0], element['l'][1]),
                                      infoWindow: InfoWindow(
                                          title: element['vehicle_number'],
                                          snippet: element['name']),
                                      anchor: const Offset(0.5, 0.5),
                                      icon: (element['is_active'] == 0)
                                          ? (element['vehicle_type_icon'] ==
                                                  'motor_bike')
                                              ? offlinebikeicon
                                              : offlineicon
                                          : (element['is_available'] == true &&
                                                  element['is_active'] == 1)
                                              ? (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onlinebikeicon
                                                  : onlineicon
                                              : (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onridebikeicon
                                                  : onrideicon,
                                    ));
                                  } else if ((element['is_active'] != 0 && myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon == offlineicon) ||
                                      (element['is_active'] != 0 &&
                                          myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon ==
                                              offlinebikeicon)) {
                                    myMarkers.removeWhere((e) => e.markerId
                                        .toString()
                                        .contains('car${element['id']}'));
                                    myMarkers.add(Marker(
                                      markerId: MarkerId('car${element['id']}'),
                                      rotation: double.parse(
                                          element['bearing'].toString()),
                                      position: LatLng(
                                          element['l'][0], element['l'][1]),
                                      infoWindow: InfoWindow(
                                          title: element['vehicle_number'],
                                          snippet: element['name']),
                                      anchor: const Offset(0.5, 0.5),
                                      icon: (element['is_active'] == 0)
                                          ? (element['vehicle_type_icon'] ==
                                                  'motor_bike')
                                              ? offlinebikeicon
                                              : offlineicon
                                          : (element['is_available'] == true &&
                                                  element['is_active'] == 1)
                                              ? (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onlinebikeicon
                                                  : onlineicon
                                              : (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onridebikeicon
                                                  : onrideicon,
                                    ));
                                  } else if ((element['is_available'] != true &&
                                          myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon ==
                                              onlineicon) ||
                                      (element['is_available'] != true &&
                                          myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon ==
                                              onlinebikeicon)) {
                                    myMarkers.removeWhere((e) => e.markerId
                                        .toString()
                                        .contains('car${element['id']}'));
                                    myMarkers.add(Marker(
                                      markerId: MarkerId('car${element['id']}'),
                                      rotation: double.parse(
                                          element['bearing'].toString()),
                                      position: LatLng(
                                          element['l'][0], element['l'][1]),
                                      infoWindow: InfoWindow(
                                          title: element['vehicle_number'],
                                          snippet: element['name']),
                                      anchor: const Offset(0.5, 0.5),
                                      icon: (element['is_active'] == 0)
                                          ? (element['vehicle_type_icon'] ==
                                                  'motor_bike')
                                              ? offlinebikeicon
                                              : offlineicon
                                          : (element['is_available'] == true &&
                                                  element['is_active'] == 1)
                                              ? (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onlinebikeicon
                                                  : onlineicon
                                              : (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onridebikeicon
                                                  : onrideicon,
                                    ));
                                  } else if ((element['is_active'] != 1 && myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon == onlineicon) ||
                                      (element['is_active'] != 1 &&
                                          myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon ==
                                              onlinebikeicon)) {
                                    myMarkers.removeWhere((e) => e.markerId
                                        .toString()
                                        .contains('car${element['id']}'));
                                    myMarkers.add(Marker(
                                      markerId: MarkerId('car${element['id']}'),
                                      rotation: double.parse(
                                          element['bearing'].toString()),
                                      position: LatLng(
                                          element['l'][0], element['l'][1]),
                                      infoWindow: InfoWindow(
                                          title: element['vehicle_number'],
                                          snippet: element['name']),
                                      anchor: const Offset(0.5, 0.5),
                                      icon: (element['is_active'] == 0)
                                          ? (element['vehicle_type_icon'] ==
                                                  'motor_bike')
                                              ? offlinebikeicon
                                              : offlineicon
                                          : (element['is_available'] == true &&
                                                  element['is_active'] == 1)
                                              ? (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onlinebikeicon
                                                  : onlineicon
                                              : (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onridebikeicon
                                                  : onrideicon,
                                    ));
                                  } else if ((element['is_available'] == true &&
                                          myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon ==
                                              onrideicon) ||
                                      (element['is_available'] == true &&
                                          myMarkers.lastWhere((e) => e.markerId.toString().contains('car${element['id']}')).icon ==
                                              onridebikeicon)) {
                                    myMarkers.removeWhere((e) => e.markerId
                                        .toString()
                                        .contains('car${element['id']}'));
                                    myMarkers.add(Marker(
                                      markerId: MarkerId('car${element['id']}'),
                                      rotation: double.parse(
                                          element['bearing'].toString()),
                                      position: LatLng(
                                          element['l'][0], element['l'][1]),
                                      infoWindow: InfoWindow(
                                          title: element['vehicle_number'],
                                          snippet: element['name']),
                                      anchor: const Offset(0.5, 0.5),
                                      icon: (element['is_active'] == 0)
                                          ? (element['vehicle_type_icon'] ==
                                                  'motor_bike')
                                              ? offlinebikeicon
                                              : offlineicon
                                          : (element['is_available'] == true &&
                                                  element['is_active'] == 1)
                                              ? (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onlinebikeicon
                                                  : onlineicon
                                              : (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onridebikeicon
                                                  : onrideicon,
                                    ));
                                  } else if (_controller != null) {
                                    if (myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .latitude !=
                                            element['l'][0] ||
                                        myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .longitude !=
                                            element['l'][1]) {
                                      var dist = calculateDistance(
                                          myMarkers
                                              .lastWhere((e) => e.markerId
                                                  .toString()
                                                  .contains(
                                                      'car${element['id']}'))
                                              .position
                                              .latitude,
                                          myMarkers
                                              .lastWhere((e) => e.markerId
                                                  .toString()
                                                  .contains(
                                                      'car${element['id']}'))
                                              .position
                                              .longitude,
                                          element['l'][0],
                                          element['l'][1]);
                                      if (dist > 100 && _controller != null) {
                                        animationController =
                                            AnimationController(
                                          duration: const Duration(
                                              milliseconds:
                                                  1500), //Animation duration of marker

                                          vsync: this, //From the widget
                                        );

                                        animateCar(
                                            myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .latitude,
                                            myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .longitude,
                                            element['l'][0],
                                            element['l'][1],
                                            _mapMarkerSink,
                                            this,
                                            _controller,
                                            'car${element['id']}',
                                            (element['is_active'] == 0)
                                                ? (element['vehicle_type_icon'] ==
                                                        'motor_bike')
                                                    ? offlinebikeicon
                                                    : offlineicon
                                                : (element['is_available'] ==
                                                            true &&
                                                        element['is_active'] ==
                                                            1)
                                                    ? (element['vehicle_type_icon'] ==
                                                            'motor_bike')
                                                        ? onlinebikeicon
                                                        : onlineicon
                                                    : (element['vehicle_type_icon'] ==
                                                            'motor_bike')
                                                        ? onridebikeicon
                                                        : onrideicon,
                                            element['vehicle_number'],
                                            element['name']);
                                      }
                                    }
                                  }
                                } else if (filtericon == 1 &&
                                    userDetails['role'] == 'owner' &&
                                    onlineicon != null) {
                                  if (element['l'] != null) {
                                    if (element['is_active'] == 0 &&
                                        offlineicon != null) {
                                      if (myMarkers
                                          .where((e) => e.markerId
                                              .toString()
                                              .contains('car${element['id']}'))
                                          .isEmpty) {
                                        myMarkers.add(Marker(
                                          markerId: MarkerId(
                                              'carid${element['id']}idoffline'),
                                          rotation: double.parse(
                                              element['bearing'].toString()),
                                          position: LatLng(
                                              element['l'][0], element['l'][1]),
                                          anchor: const Offset(0.5, 0.5),
                                          icon: (element['vehicle_type_icon'] ==
                                                  'motor_bike')
                                              ? offlinebikeicon
                                              : offlineicon,
                                        ));
                                      } else if (_controller != null) {
                                        if (myMarkers
                                                    .lastWhere((e) => e.markerId
                                                        .toString()
                                                        .contains(
                                                            'car${element['id']}'))
                                                    .position
                                                    .latitude !=
                                                element['l'][0] ||
                                            myMarkers
                                                    .lastWhere((e) => e.markerId
                                                        .toString()
                                                        .contains(
                                                            'car${element['id']}'))
                                                    .position
                                                    .longitude !=
                                                element['l'][1]) {
                                          var dist = calculateDistance(
                                              myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .latitude,
                                              myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .longitude,
                                              element['l'][0],
                                              element['l'][1]);
                                          if (dist > 100 &&
                                              _controller != null) {
                                            animationController =
                                                AnimationController(
                                              duration: const Duration(
                                                  milliseconds:
                                                      1500), //Animation duration of marker

                                              vsync: this, //From the widget
                                            );

                                            animateCar(
                                                myMarkers
                                                    .lastWhere((e) => e.markerId
                                                        .toString()
                                                        .contains(
                                                            'car${element['id']}'))
                                                    .position
                                                    .latitude,
                                                myMarkers
                                                    .lastWhere((e) => e.markerId
                                                        .toString()
                                                        .contains(
                                                            'car${element['id']}'))
                                                    .position
                                                    .longitude,
                                                element['l'][0],
                                                element['l'][1],
                                                _mapMarkerSink,
                                                this,
                                                _controller,
                                                'car${element['id']}',
                                                (element['vehicle_type_icon'] ==
                                                        'motor_bike')
                                                    ? offlinebikeicon
                                                    : offlineicon,
                                                element['vehicle_number'],
                                                element['name']);
                                          }
                                        }
                                      }
                                    } else {
                                      if (myMarkers
                                          .where((e) => e.markerId
                                              .toString()
                                              .contains('car${element['id']}'))
                                          .isNotEmpty) {
                                        myMarkers.removeWhere((e) => e.markerId
                                            .toString()
                                            .contains('car${element['id']}'));
                                      }
                                    }
                                  }
                                } else if (filtericon == 2 &&
                                    userDetails['role'] == 'owner' &&
                                    onlineicon != null) {
                                  if (element['is_available'] == false &&
                                      element['is_active'] == 1) {
                                    if (myMarkers
                                        .where((e) => e.markerId
                                            .toString()
                                            .contains('car${element['id']}'))
                                        .isEmpty) {
                                      myMarkers.add(Marker(
                                        markerId:
                                            MarkerId('car${element['id']}'),
                                        rotation: double.parse(
                                            element['bearing'].toString()),
                                        position: LatLng(
                                            element['l'][0], element['l'][1]),
                                        anchor: const Offset(0.5, 0.5),
                                        icon: (element['vehicle_type_icon'] ==
                                                'motor_bike')
                                            ? onridebikeicon
                                            : onrideicon,
                                      ));
                                    } else if (_controller != null) {
                                      if (myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .latitude !=
                                              element['l'][0] ||
                                          myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .longitude !=
                                              element['l'][1]) {
                                        var dist = calculateDistance(
                                            myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .latitude,
                                            myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .longitude,
                                            element['l'][0],
                                            element['l'][1]);
                                        if (dist > 100 && _controller != null) {
                                          animationController =
                                              AnimationController(
                                            duration: const Duration(
                                                milliseconds:
                                                    1500), //Animation duration of marker

                                            vsync: this, //From the widget
                                          );

                                          animateCar(
                                              myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .latitude,
                                              myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .longitude,
                                              element['l'][0],
                                              element['l'][1],
                                              _mapMarkerSink,
                                              this,
                                              _controller,
                                              'car${element['id']}',
                                              (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onridebikeicon
                                                  : onrideicon,
                                              element['vehicle_number'],
                                              element['name']);
                                        }
                                      }
                                    }
                                  } else {
                                    if (myMarkers
                                        .where((e) => e.markerId
                                            .toString()
                                            .contains('car${element['id']}'))
                                        .isNotEmpty) {
                                      myMarkers.removeWhere((e) => e.markerId
                                          .toString()
                                          .contains('car${element['id']}'));
                                    }
                                  }
                                } else if (filtericon == 3 &&
                                    userDetails['role'] == 'owner' &&
                                    onlineicon != null) {
                                  if (element['is_available'] == true &&
                                      element['is_active'] == 1) {
                                    if (myMarkers
                                        .where((e) => e.markerId
                                            .toString()
                                            .contains('car${element['id']}'))
                                        .isEmpty) {
                                      myMarkers.add(Marker(
                                        markerId:
                                            MarkerId('car${element['id']}'),
                                        rotation: double.parse(
                                            element['bearing'].toString()),
                                        position: LatLng(
                                            element['l'][0], element['l'][1]),
                                        anchor: const Offset(0.5, 0.5),
                                        icon: (element['vehicle_type_icon'] ==
                                                'motor_bike')
                                            ? onlinebikeicon
                                            : onlineicon,
                                      ));
                                    } else if (_controller != null) {
                                      if (myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .latitude !=
                                              element['l'][0] ||
                                          myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .longitude !=
                                              element['l'][1]) {
                                        var dist = calculateDistance(
                                            myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .latitude,
                                            myMarkers
                                                .lastWhere((e) => e.markerId
                                                    .toString()
                                                    .contains(
                                                        'car${element['id']}'))
                                                .position
                                                .longitude,
                                            element['l'][0],
                                            element['l'][1]);
                                        if (dist > 100 && _controller != null) {
                                          animationController =
                                              AnimationController(
                                            duration: const Duration(
                                                milliseconds:
                                                    1500), //Animation duration of marker

                                            vsync: this, //From the widget
                                          );

                                          animateCar(
                                              myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .latitude,
                                              myMarkers
                                                  .lastWhere((e) => e.markerId
                                                      .toString()
                                                      .contains(
                                                          'car${element['id']}'))
                                                  .position
                                                  .longitude,
                                              element['l'][0],
                                              element['l'][1],
                                              _mapMarkerSink,
                                              this,
                                              _controller,
                                              'car${element['id']}',
                                              (element['vehicle_type_icon'] ==
                                                      'motor_bike')
                                                  ? onlinebikeicon
                                                  : onlineicon,
                                              element['vehicle_number'],
                                              element['name']);
                                        }
                                      }
                                    }
                                  }
                                } else {
                                  if (myMarkers
                                      .where((e) => e.markerId
                                          .toString()
                                          .contains('car${element['id']}'))
                                      .isNotEmpty) {
                                    myMarkers.removeWhere((e) => e.markerId
                                        .toString()
                                        .contains('car${element['id']}'));
                                  }
                                }
                              }
                            } else {
                              if (myMarkers
                                  .where((e) => e.markerId
                                      .toString()
                                      .contains('car${element['id']}'))
                                  .isNotEmpty) {
                                myMarkers.removeWhere((e) => e.markerId
                                    .toString()
                                    .contains('car${element['id']}'));
                              }
                            }
                          }
                        }
                        return SingleChildScrollView(
                          child: Stack(
                            children: [
                              Container(
                                color: page,
                                height: media.height * 1,
                                width: media.width * 1,
                                child: Column(
                                    mainAxisAlignment:
                                        (state == '1' || state == '2')
                                            ? MainAxisAlignment.center
                                            : MainAxisAlignment.start,
                                    children: [
                                      (state == '1')
                                          ? Container(
                                              padding: EdgeInsets.all(
                                                  media.width * 0.05),
                                              width: media.width * 0.6,
                                              height: media.width * 0.3,
                                              decoration: BoxDecoration(
                                                  color: page,
                                                  boxShadow: [
                                                    BoxShadow(
                                                        blurRadius: 5,
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        spreadRadius: 2)
                                                  ],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    languages[choosenLanguage][
                                                        'text_enable_location'],
                                                    style: GoogleFonts.roboto(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Container(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          state = '';
                                                        });
                                                        getLocs();
                                                      },
                                                      child: Text(
                                                        languages[
                                                                choosenLanguage]
                                                            ['text_ok'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: media
                                                                        .width *
                                                                    twenty,
                                                                color:
                                                                    buttonColor),
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            )
                                          : (state == '2')
                                              ? Container(
                                                  height: media.height * 1,
                                                  width: media.width * 1,
                                                  alignment: Alignment.center,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      SizedBox(
                                                        height:
                                                            media.height * 0.31,
                                                        child: Image.asset(
                                                          'assets/images/allow_location_permission.png',
                                                          fit: BoxFit.contain,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            media.width * 0.05,
                                                      ),
                                                      Text(
                                                        languages[
                                                                choosenLanguage]
                                                            [
                                                            'text_trustedtaxi'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                                color:
                                                                    textColor,
                                                                fontSize: media
                                                                        .width *
                                                                    eighteen,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600),
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            media.width * 0.025,
                                                      ),
                                                      Text(
                                                        languages[
                                                                choosenLanguage]
                                                            [
                                                            'text_allowpermission1'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                          color: textColor,
                                                          fontSize:
                                                              media.width *
                                                                  fourteen,
                                                        ),
                                                      ),
                                                      Text(
                                                        languages[
                                                                choosenLanguage]
                                                            [
                                                            'text_allowpermission2'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                          color: textColor,
                                                          fontSize:
                                                              media.width *
                                                                  fourteen,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            media.width * 0.05,
                                                      ),
                                                      Container(
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                                media.width *
                                                                    0.05,
                                                                0,
                                                                media.width *
                                                                    0.05,
                                                                0),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          children: [
                                                            SizedBox(
                                                                width: media
                                                                        .width *
                                                                    0.075,
                                                                child: Icon(
                                                                    Icons
                                                                        .location_on_outlined,
                                                                    color:
                                                                        textColor)),
                                                            SizedBox(
                                                              width:
                                                                  media.width *
                                                                      0.025,
                                                            ),
                                                            SizedBox(
                                                              width:
                                                                  media.width *
                                                                      0.8,
                                                              child: Text(
                                                                languages[
                                                                        choosenLanguage]
                                                                    [
                                                                    'text_loc_permission'],
                                                                style: GoogleFonts.roboto(
                                                                    color:
                                                                        textColor,
                                                                    fontSize: media
                                                                            .width *
                                                                        fourteen,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            media.width * 0.02,
                                                      ),
                                                      Container(
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                                media.width *
                                                                    0.05,
                                                                0,
                                                                media.width *
                                                                    0.05,
                                                                0),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          children: [
                                                            SizedBox(
                                                                width: media
                                                                        .width *
                                                                    0.075,
                                                                child: Icon(
                                                                    Icons
                                                                        .location_on_outlined,
                                                                    color:
                                                                        textColor)),
                                                            SizedBox(
                                                              width:
                                                                  media.width *
                                                                      0.025,
                                                            ),
                                                            SizedBox(
                                                              width:
                                                                  media.width *
                                                                      0.8,
                                                              child: Text(
                                                                languages[
                                                                        choosenLanguage]
                                                                    [
                                                                    'text_background_permission'],
                                                                style: GoogleFonts.roboto(
                                                                    color:
                                                                        textColor,
                                                                    fontSize: media
                                                                            .width *
                                                                        fourteen,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  media.width *
                                                                      0.05),
                                                          child: Button(
                                                              onTap: () async {
                                                                getLocationPermission();
                                                              },
                                                              text: languages[
                                                                      choosenLanguage]
                                                                  [
                                                                  'text_allow']))
                                                    ],
                                                  ),
                                                )
                                              : (state == '3')
                                                  ? Stack(
                                                      alignment:
                                                          Alignment.center,
                                                      children: [
                                                        SizedBox(
                                                            height:
                                                                media.height *
                                                                    1,
                                                            width:
                                                                media.width * 1,
                                                            //google maps
                                                            child: StreamBuilder<
                                                                    List<
                                                                        Marker>>(
                                                                stream:
                                                                    mapMarkerStream,
                                                                builder: (context,
                                                                    snapshot) {
                                                                  return GoogleMap(
                                                                    padding: EdgeInsets.only(
                                                                        bottom:
                                                                            mapPadding,
                                                                        top: media.height *
                                                                                0.1 +
                                                                            MediaQuery.of(context).padding.top),
                                                                    onMapCreated:
                                                                        _onMapCreated,
                                                                    mapToolbarEnabled:
                                                                        false,
                                                                    initialCameraPosition:
                                                                        CameraPosition(
                                                                      target: (center ==
                                                                              null)
                                                                          ? _center
                                                                          : center,
                                                                      zoom:
                                                                          11.0,
                                                                    ),
                                                                    markers: Set<
                                                                            Marker>.from(
                                                                        myMarkers),
                                                                    polylines:
                                                                        polyline,
                                                                    minMaxZoomPreference:
                                                                        const MinMaxZoomPreference(
                                                                            0.0,
                                                                            20.0),
                                                                    myLocationButtonEnabled:
                                                                        false,
                                                                    compassEnabled:
                                                                        false,
                                                                    buildingsEnabled:
                                                                        false,
                                                                    zoomControlsEnabled:
                                                                        false,
                                                                  );
                                                                })),

                                                        //driver status
                                                        (userDetails['role'] ==
                                                                'owner')
                                                            ? Container()
                                                            : Positioned(
                                                                top: MediaQuery.of(
                                                                            context)
                                                                        .padding
                                                                        .top +
                                                                    25,
                                                                child:
                                                                    Container(
                                                                  padding: EdgeInsets.fromLTRB(
                                                                      media.width *
                                                                          0.05,
                                                                      media.width *
                                                                          0.025,
                                                                      media.width *
                                                                          0.05,
                                                                      media.width *
                                                                          0.025),
                                                                  decoration: BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              10),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                            blurRadius:
                                                                                2,
                                                                            color:
                                                                                Colors.black.withOpacity(0.2),
                                                                            spreadRadius: 2)
                                                                      ],
                                                                      color:
                                                                          page),
                                                                  //driver status display
                                                                  child: Row(
                                                                    children: [
                                                                      Container(
                                                                        height:
                                                                            10,
                                                                        width:
                                                                            10,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                                shape: BoxShape
                                                                                    .circle,
                                                                                boxShadow: [
                                                                                  BoxShadow(blurRadius: 2, color: Colors.black.withOpacity(0.2), spreadRadius: 2)
                                                                                ],
                                                                                color: (driverReq.isEmpty)
                                                                                    ? (userDetails['active'] == false)
                                                                                        ? const Color(0xff666666)
                                                                                        : const Color(0xff319900)
                                                                                    : (driverReq['accepted_at'] != null && driverReq['arrived_at'] == null)
                                                                                        ? const Color(0xff2E67D5)
                                                                                        : (driverReq['accepted_at'] != null && driverReq['arrived_at'] != null && driverReq['is_trip_start'] == 0)
                                                                                            ? const Color(0xff319900)
                                                                                            : (driverReq['accepted_at'] != null && driverReq['arrived_at'] != null && driverReq['is_trip_start'] != null)
                                                                                                ? const Color(0xffFF0000)
                                                                                                : (driverReq['accepted'] == null && userDetails['active'] == false)
                                                                                                    ? const Color(0xff666666)
                                                                                                    : const Color(0xff319900)),
                                                                      ),
                                                                      SizedBox(
                                                                        width: media.width *
                                                                            0.02,
                                                                      ),
                                                                      Text(
                                                                        (driverReq.isEmpty)
                                                                            ? (userDetails['active'] == false)
                                                                                ? languages[choosenLanguage]['text_youareoffline']
                                                                                : languages[choosenLanguage]['text_youareonline']
                                                                            : (driverReq['accepted_at'] != null && driverReq['arrived_at'] == null)
                                                                                ? languages[choosenLanguage]['text_arriving']
                                                                                : (driverReq['accepted_at'] != null && driverReq['arrived_at'] != null && driverReq['is_trip_start'] == 0)
                                                                                    ? languages[choosenLanguage]['text_arrived']
                                                                                    : (driverReq['accepted_at'] != null && driverReq['arrived_at'] != null && driverReq['is_trip_start'] != null)
                                                                                        ? languages[choosenLanguage]['text_onride']
                                                                                        : (driverReq['accepted'] == null && userDetails['active'] == false)
                                                                                            ? languages[choosenLanguage]['text_youareoffline']
                                                                                            : languages[choosenLanguage]['text_youareonline'],
                                                                        style: GoogleFonts.roboto(
                                                                            fontSize: media.width * twelve,
                                                                            color: (driverReq.isEmpty)
                                                                                ? (userDetails['active'] == false)
                                                                                    ? const Color(0xff666666)
                                                                                    : const Color(0xff319900)
                                                                                : (driverReq['accepted_at'] != null && driverReq['arrived_at'] == null)
                                                                                    ? const Color(0xff2E67D5)
                                                                                    : (driverReq['accepted_at'] != null && driverReq['arrived_at'] != null && driverReq['is_trip_start'] == 0)
                                                                                        ? const Color(0xff319900)
                                                                                        : (driverReq['accepted_at'] != null && driverReq['arrived_at'] != null && driverReq['is_trip_start'] == 1)
                                                                                            ? const Color(0xffFF0000)
                                                                                            : (driverReq['accepted'] == null && userDetails['active'] == false)
                                                                                                ? const Color(0xff666666)
                                                                                                : const Color(0xff319900)),
                                                                      )
                                                                    ],
                                                                  ),
                                                                )),
                                                        //menu bar
                                                        Positioned(
                                                            top: MediaQuery.of(
                                                                        context)
                                                                    .padding
                                                                    .top +
                                                                12.5,
                                                            child: SizedBox(
                                                              width:
                                                                  media.width *
                                                                      0.9,
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Container(
                                                                    height:
                                                                        media.width *
                                                                            0.1,
                                                                    width: media
                                                                            .width *
                                                                        0.1,
                                                                    decoration: BoxDecoration(
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                              blurRadius: 2,
                                                                              color: Colors.black.withOpacity(0.2),
                                                                              spreadRadius: 2)
                                                                        ],
                                                                        color:
                                                                            page,
                                                                        borderRadius:
                                                                            BorderRadius.circular(media.width *
                                                                                0.02)),
                                                                    child: StatefulBuilder(builder:
                                                                        (context,
                                                                            setState) {
                                                                      return InkWell(
                                                                          onTap:
                                                                              () async {
                                                                            Scaffold.of(context).openDrawer();
                                                                          },
                                                                          child: Icon(
                                                                              Icons.menu,
                                                                              color: textColor));
                                                                    }),
                                                                  ),
                                                                ],
                                                              ),
                                                            )),
                                                        //drivers filter for owner
                                                        (userDetails['role'] ==
                                                                'owner')
                                                            ? (languageDirection ==
                                                                    'rtl')
                                                                ? Positioned(
                                                                    top: MediaQuery.of(context)
                                                                            .padding
                                                                            .top +
                                                                        12.5,
                                                                    left: 10,
                                                                    child:
                                                                        Container(
                                                                      height: media
                                                                              .width *
                                                                          0.13,
                                                                      width: (show == true)
                                                                          ? media.width *
                                                                              0.13
                                                                          : media.width *
                                                                              0.7,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius: show ==
                                                                                true
                                                                            ? BorderRadius.circular(
                                                                                100.0)
                                                                            : const BorderRadius.only(
                                                                                topLeft: Radius.circular(100),
                                                                                bottomLeft: Radius.circular(100),
                                                                                topRight: Radius.circular(20),
                                                                                bottomRight: Radius.circular(20)),
                                                                        color: Colors
                                                                            .white,
                                                                        boxShadow: const [
                                                                          BoxShadow(
                                                                            color: ui.Color.fromARGB(
                                                                                255,
                                                                                8,
                                                                                38,
                                                                                172),
                                                                            offset:
                                                                                Offset(0.0, 1.0), //(x,y)
                                                                            blurRadius:
                                                                                10.0,
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      child:
                                                                          Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          show == false
                                                                              ? SizedBox(
                                                                                  width: media.width * 0.57,
                                                                                  child: Row(
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                                    children: [
                                                                                      OwnerCarImagecontainer(
                                                                                        color: Colors.green,
                                                                                        imgurl: 'assets/images/available.png',
                                                                                        text: languages[choosenLanguage]['text_available'],
                                                                                        ontap: () {
                                                                                          setState(() {
                                                                                            filtericon = 3;
                                                                                            myMarkers.clear();
                                                                                          });
                                                                                        },
                                                                                      ),
                                                                                      OwnerCarImagecontainer(
                                                                                        color: Colors.red,
                                                                                        imgurl: 'assets/images/onboard.png',
                                                                                        text: languages[choosenLanguage]['text_onboard'],
                                                                                        ontap: () {
                                                                                          setState(() {
                                                                                            filtericon = 2;
                                                                                            myMarkers.clear();
                                                                                          });
                                                                                        },
                                                                                      ),
                                                                                      OwnerCarImagecontainer(
                                                                                        color: Colors.grey,
                                                                                        imgurl: 'assets/images/offlinecar.png',
                                                                                        text: languages[choosenLanguage]['text_offline'],
                                                                                        ontap: () {
                                                                                          setState(() {
                                                                                            filtericon = 1;
                                                                                            myMarkers.clear();
                                                                                          });
                                                                                        },
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                )
                                                                              : Container(),
                                                                          InkWell(
                                                                            onTap:
                                                                                () {
                                                                              setState(() {
                                                                                filtericon = 0;
                                                                                myMarkers.clear();
                                                                                if (show == false) {
                                                                                  show = true;
                                                                                } else {
                                                                                  show = false;
                                                                                }
                                                                              });
                                                                            },
                                                                            child:
                                                                                Container(
                                                                              width: media.width * 0.13,
                                                                              decoration: BoxDecoration(image: const DecorationImage(image: AssetImage('assets/images/bluecar.png'), fit: BoxFit.contain), borderRadius: BorderRadius.circular(100.0)),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  )
                                                                : Positioned(
                                                                    top: MediaQuery.of(context)
                                                                            .padding
                                                                            .top +
                                                                        12.5,
                                                                    right: 10,
                                                                    child:
                                                                        Container(
                                                                      height: media
                                                                              .width *
                                                                          0.13,
                                                                      width: (show == true)
                                                                          ? media.width *
                                                                              0.13
                                                                          : media.width *
                                                                              0.7,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius: show ==
                                                                                true
                                                                            ? BorderRadius.circular(
                                                                                100.0)
                                                                            : const BorderRadius.only(
                                                                                topLeft: Radius.circular(20),
                                                                                bottomLeft: Radius.circular(20),
                                                                                topRight: Radius.circular(100),
                                                                                bottomRight: Radius.circular(100)),
                                                                        color: Colors
                                                                            .white,
                                                                        boxShadow: const [
                                                                          BoxShadow(
                                                                            color: ui.Color.fromARGB(
                                                                                255,
                                                                                8,
                                                                                38,
                                                                                172),
                                                                            offset:
                                                                                Offset(0.0, 1.0), //(x,y)
                                                                            blurRadius:
                                                                                10.0,
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      child:
                                                                          Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          show == false
                                                                              ? SizedBox(
                                                                                  width: media.width * 0.57,
                                                                                  child: Row(
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                                    children: [
                                                                                      OwnerCarImagecontainer(
                                                                                        color: Colors.green,
                                                                                        imgurl: 'assets/images/available.png',
                                                                                        text: languages[choosenLanguage]['text_available'],
                                                                                        ontap: () {
                                                                                          setState(() {
                                                                                            filtericon = 3;
                                                                                            myMarkers.clear();
                                                                                          });
                                                                                        },
                                                                                      ),
                                                                                      OwnerCarImagecontainer(
                                                                                        color: Colors.red,
                                                                                        imgurl: 'assets/images/onboard.png',
                                                                                        text: languages[choosenLanguage]['text_onboard'],
                                                                                        ontap: () {
                                                                                          setState(() {
                                                                                            filtericon = 2;
                                                                                            myMarkers.clear();
                                                                                          });
                                                                                        },
                                                                                      ),
                                                                                      OwnerCarImagecontainer(
                                                                                        color: Colors.grey,
                                                                                        imgurl: 'assets/images/offlinecar.png',
                                                                                        text: 'Offline',
                                                                                        ontap: () {
                                                                                          setState(() {
                                                                                            filtericon = 1;
                                                                                            myMarkers.clear();
                                                                                          });
                                                                                        },
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                )
                                                                              : Container(),
                                                                          InkWell(
                                                                            onTap:
                                                                                () {
                                                                              setState(() {
                                                                                filtericon = 0;
                                                                                myMarkers.clear();
                                                                                if (show == false) {
                                                                                  show = true;
                                                                                } else {
                                                                                  show = false;
                                                                                }
                                                                              });
                                                                            },
                                                                            child:
                                                                                Container(
                                                                              width: media.width * 0.13,
                                                                              decoration: BoxDecoration(image: const DecorationImage(image: AssetImage('assets/images/bluecar.png'), fit: BoxFit.contain), borderRadius: BorderRadius.circular(100.0)),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  )
                                                            : Container(),

                                                        //online or offline button
                                                        (userDetails['low_balance'] ==
                                                                    false) &&
                                                                (userDetails[
                                                                            'role'] ==
                                                                        'driver' &&
                                                                    (userDetails['vehicle_type_id'] !=
                                                                            null ||
                                                                        userDetails['vehicle_types']
                                                                            .isNotEmpty))
                                                            ? Positioned(
                                                                bottom: 25,
                                                                child: InkWell(
                                                                  onTap:
                                                                      () async {
                                                                    if (locationAllowed ==
                                                                            true &&
                                                                        serviceEnabled ==
                                                                            true) {
                                                                      setState(
                                                                          () {
                                                                        _isLoading =
                                                                            true;
                                                                      });

                                                                      var val =
                                                                          await driverStatus();
                                                                      if (val ==
                                                                          'logout') {
                                                                        navigateLogout();
                                                                      }
                                                                      setState(
                                                                          () {
                                                                        _isLoading =
                                                                            false;
                                                                      });
                                                                    } else if (locationAllowed ==
                                                                            true &&
                                                                        serviceEnabled ==
                                                                            false) {
                                                                      await geolocator.Geolocator.getCurrentPosition(
                                                                          desiredAccuracy: geolocator
                                                                              .LocationAccuracy
                                                                              .low);
                                                                      if (await geolocator
                                                                          .GeolocatorPlatform
                                                                          .instance
                                                                          .isLocationServiceEnabled()) {
                                                                        serviceEnabled =
                                                                            true;
                                                                        setState(
                                                                            () {
                                                                          _isLoading =
                                                                              true;
                                                                        });

                                                                        var val =
                                                                            await driverStatus();
                                                                        if (val ==
                                                                            'logout') {
                                                                          navigateLogout();
                                                                        }
                                                                        setState(
                                                                            () {
                                                                          _isLoading =
                                                                              false;
                                                                        });
                                                                      }
                                                                    } else {
                                                                      if (serviceEnabled ==
                                                                          true) {
                                                                        setState(
                                                                            () {
                                                                          makeOnline =
                                                                              true;
                                                                          _locationDenied =
                                                                              true;
                                                                        });
                                                                      } else {
                                                                        await geolocator.Geolocator.getCurrentPosition(
                                                                            desiredAccuracy:
                                                                                geolocator.LocationAccuracy.low);
                                                                        setState(
                                                                            () {
                                                                          _isLoading =
                                                                              true;
                                                                        });
                                                                        await getLocs();
                                                                        if (serviceEnabled ==
                                                                            true) {
                                                                          setState(
                                                                              () {
                                                                            makeOnline =
                                                                                true;
                                                                            _locationDenied =
                                                                                true;
                                                                          });
                                                                        }
                                                                      }
                                                                    }
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    padding: EdgeInsets.only(
                                                                        left: media.width *
                                                                            0.01,
                                                                        right: media.width *
                                                                            0.01),
                                                                    height: media
                                                                            .width *
                                                                        0.08,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(media.width *
                                                                              0.04),
                                                                      color: (userDetails['active'] ==
                                                                              false)
                                                                          ? offline
                                                                          : online,
                                                                    ),
                                                                    child: (userDetails['active'] ==
                                                                            false)
                                                                        ? Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Container(),
                                                                              SizedBox(width: media.width * 0.025),
                                                                              Text(
                                                                                languages[choosenLanguage]['text_off_duty'],
                                                                                style: GoogleFonts.roboto(fontSize: media.width * twelve, color: onlineOfflineText),
                                                                              ),
                                                                              SizedBox(width: media.width * 0.025),
                                                                              Container(
                                                                                padding: EdgeInsets.all(media.width * 0.01),
                                                                                height: media.width * 0.07,
                                                                                width: media.width * 0.07,
                                                                                decoration: BoxDecoration(shape: BoxShape.circle, color: onlineOfflineText),
                                                                                child: Image.asset('assets/images/offline.png'),
                                                                              )
                                                                            ],
                                                                          )
                                                                        : Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Container(
                                                                                padding: EdgeInsets.all(media.width * 0.01),
                                                                                height: media.width * 0.07,
                                                                                width: media.width * 0.07,
                                                                                decoration: BoxDecoration(shape: BoxShape.circle, color: onlineOfflineText),
                                                                                child: Image.asset('assets/images/online.png'),
                                                                              ),
                                                                              SizedBox(width: media.width * 0.025),
                                                                              Text(
                                                                                languages[choosenLanguage]['text_on_duty'],
                                                                                style: GoogleFonts.roboto(fontSize: media.width * twelve, color: onlineOfflineText),
                                                                              ),
                                                                              SizedBox(width: media.width * 0.025),
                                                                              Container(),
                                                                            ],
                                                                          ),
                                                                  ),
                                                                ))
                                                            : (userDetails['role'] ==
                                                                        'driver' &&
                                                                    userDetails[
                                                                            'vehicle_type_id'] ==
                                                                        null &&
                                                                    userDetails[
                                                                            'vehicle_types']
                                                                        .isEmpty)
                                                                ? Positioned(
                                                                    bottom: 0,
                                                                    child:
                                                                        Container(
                                                                      color:
                                                                          buttonColor,
                                                                      width:
                                                                          media.width *
                                                                              1,
                                                                      padding: EdgeInsets.all(
                                                                          media.width *
                                                                              0.05),
                                                                      child:
                                                                          Text(
                                                                        languages[choosenLanguage]
                                                                            [
                                                                            'text_no_fleet_assigned'],
                                                                        style: GoogleFonts
                                                                            .roboto(
                                                                          fontSize:
                                                                              media.width * fourteen,
                                                                          color: (isDarkTheme == true)
                                                                              ? Colors.black
                                                                              : Colors.white,
                                                                        ),
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                      ),
                                                                    ),
                                                                  )
                                                                : (userDetails
                                                                            .isNotEmpty &&
                                                                        userDetails['low_balance'] ==
                                                                            true)
                                                                    ?
                                                                    //low balance
                                                                    Positioned(
                                                                        bottom:
                                                                            0,
                                                                        child:
                                                                            Container(
                                                                          color:
                                                                              buttonColor,
                                                                          width:
                                                                              media.width * 1,
                                                                          padding:
                                                                              EdgeInsets.all(media.width * 0.05),
                                                                          child:
                                                                              Text(
                                                                            languages[choosenLanguage]['text_low_balance'],
                                                                            style:
                                                                                GoogleFonts.roboto(
                                                                              fontSize: media.width * fourteen,
                                                                              color: Colors.white,
                                                                            ),
                                                                            textAlign:
                                                                                TextAlign.center,
                                                                          ),
                                                                        ),
                                                                      )
                                                                    : Container(),

                                                        //request popup accept or reject
                                                        Positioned(
                                                            bottom: 20,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .end,
                                                              children: [
                                                                (driverReq.isNotEmpty &&
                                                                        driverReq['is_trip_start'] ==
                                                                            1)
                                                                    ? InkWell(
                                                                        onTap:
                                                                            () async {
                                                                          setState(
                                                                              () {
                                                                            showSos =
                                                                                true;
                                                                          });
                                                                        },
                                                                        child:
                                                                            Container(
                                                                          height:
                                                                              media.width * 0.1,
                                                                          width:
                                                                              media.width * 0.1,
                                                                          decoration: BoxDecoration(
                                                                              boxShadow: [
                                                                                BoxShadow(blurRadius: 2, color: Colors.black.withOpacity(0.2), spreadRadius: 2)
                                                                              ],
                                                                              color: buttonColor,
                                                                              borderRadius: BorderRadius.circular(media.width * 0.02)),
                                                                          alignment:
                                                                              Alignment.center,
                                                                          child:
                                                                              Text(
                                                                            'SOS',
                                                                            style:
                                                                                GoogleFonts.roboto(fontSize: media.width * fourteen, color: page),
                                                                          ),
                                                                        ))
                                                                    : Container(),
                                                                const SizedBox(
                                                                  height: 20,
                                                                ),
                                                                (driverReq.isNotEmpty &&
                                                                        driverReq['accepted_at'] !=
                                                                            null)
                                                                    ? InkWell(
                                                                        onTap:
                                                                            () async {
                                                                          if (driverReq['is_trip_start'] ==
                                                                              0) {
                                                                            openMap(driverReq['pick_lat'],
                                                                                driverReq['pick_lng']);
                                                                          } else if (tripStops
                                                                              .isNotEmpty) {
                                                                            setState(() {
                                                                              _tripOpenMap = true;
                                                                            });
                                                                          } else {
                                                                            openMap(driverReq['drop_lat'],
                                                                                driverReq['drop_lng']);
                                                                          }
                                                                        },
                                                                        child: Container(
                                                                            height: media.width *
                                                                                0.1,
                                                                            width: media.width *
                                                                                0.1,
                                                                            decoration:
                                                                                BoxDecoration(boxShadow: [
                                                                              BoxShadow(blurRadius: 2, color: Colors.black.withOpacity(0.2), spreadRadius: 2)
                                                                            ], color: page, borderRadius: BorderRadius.circular(media.width * 0.02)),
                                                                            alignment: Alignment.center,
                                                                            child: Image.asset('assets/images/locationFind.png', width: media.width * 0.06, color: textColor)),
                                                                      )
                                                                    : Container(),
                                                                const SizedBox(
                                                                    height: 20),
                                                                //animate to current location button
                                                                InkWell(
                                                                  onTap:
                                                                      () async {
                                                                    if (locationAllowed ==
                                                                        true) {
                                                                      _controller?.animateCamera(CameraUpdate.newLatLngZoom(
                                                                          center,
                                                                          18.0));
                                                                    } else {
                                                                      if (serviceEnabled ==
                                                                          true) {
                                                                        setState(
                                                                            () {
                                                                          _locationDenied =
                                                                              true;
                                                                        });
                                                                      } else {
                                                                        await geolocator.Geolocator.getCurrentPosition(
                                                                            desiredAccuracy:
                                                                                geolocator.LocationAccuracy.low);

                                                                        setState(
                                                                            () {
                                                                          _isLoading =
                                                                              true;
                                                                        });
                                                                        await getLocs();
                                                                        if (serviceEnabled ==
                                                                            true) {
                                                                          setState(
                                                                              () {
                                                                            _locationDenied =
                                                                                true;
                                                                          });
                                                                        }
                                                                      }
                                                                    }
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    height:
                                                                        media.width *
                                                                            0.1,
                                                                    width: media
                                                                            .width *
                                                                        0.1,
                                                                    decoration: BoxDecoration(
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                              blurRadius: 2,
                                                                              color: Colors.black.withOpacity(0.2),
                                                                              spreadRadius: 2)
                                                                        ],
                                                                        color:
                                                                            page,
                                                                        borderRadius:
                                                                            BorderRadius.circular(media.width *
                                                                                0.02)),
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    child: Icon(
                                                                        Icons
                                                                            .my_location_sharp,
                                                                        size: media.width *
                                                                            0.06,
                                                                        color:
                                                                            textColor),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                    height: media
                                                                            .width *
                                                                        0.25),
                                                                (driverReq
                                                                        .isNotEmpty)
                                                                    ? (driverReq['accepted_at'] ==
                                                                            null)
                                                                        ? Column(
                                                                            children: [
                                                                              (driverReq['is_later'] == 1 && driverReq['is_rental'] != true)
                                                                                  ? Container(
                                                                                      alignment: Alignment.center,
                                                                                      margin: EdgeInsets.only(bottom: media.width * 0.025),
                                                                                      padding: EdgeInsets.all(media.width * 0.025),
                                                                                      decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(6)),
                                                                                      width: media.width * 0.9,
                                                                                      child: Text(
                                                                                        languages[choosenLanguage]['text_rideLaterTime'] + " " + driverReq['cv_trip_start_time'],
                                                                                        style: GoogleFonts.roboto(fontSize: media.width * sixteen, color: Colors.white),
                                                                                      ),
                                                                                    )
                                                                                  : (driverReq['is_rental'] == true && driverReq['is_later'] != 1)
                                                                                      ? Container(
                                                                                          alignment: Alignment.center,
                                                                                          margin: EdgeInsets.only(bottom: media.width * 0.025),
                                                                                          padding: EdgeInsets.all(media.width * 0.025),
                                                                                          decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(6)),
                                                                                          width: media.width * 0.9,
                                                                                          child: Text(
                                                                                            languages[choosenLanguage]['text_rental_ride'] + ' - ' + driverReq['rental_package_name'],
                                                                                            style: GoogleFonts.roboto(fontSize: media.width * sixteen, color: Colors.white),
                                                                                          ),
                                                                                        )
                                                                                      : (driverReq['is_rental'] == true && driverReq['is_later'] == 1)
                                                                                          ? Container(
                                                                                              alignment: Alignment.center,
                                                                                              margin: EdgeInsets.only(bottom: media.width * 0.025),
                                                                                              padding: EdgeInsets.all(media.width * 0.025),
                                                                                              decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(6)),
                                                                                              width: media.width * 0.9,
                                                                                              child: Column(
                                                                                                children: [
                                                                                                  Text(
                                                                                                    languages[choosenLanguage]['text_rideLaterTime'] + " " + driverReq['cv_trip_start_time'],
                                                                                                    style: GoogleFonts.roboto(fontSize: media.width * sixteen, color: Colors.white),
                                                                                                  ),
                                                                                                  SizedBox(height: media.width * 0.02),
                                                                                                  Text(
                                                                                                    languages[choosenLanguage]['text_rental_ride'] + ' - ' + driverReq['rental_package_name'],
                                                                                                    style: GoogleFonts.roboto(fontSize: media.width * sixteen, color: Colors.white),
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                            )
                                                                                          : Container(),
                                                                              Container(
                                                                                  padding: const EdgeInsets.fromLTRB(0, 0, 0,
                                                                                      0),
                                                                                  width: media.width *
                                                                                      0.9,
                                                                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: page, boxShadow: [
                                                                                    BoxShadow(blurRadius: 2, color: Colors.black.withOpacity(0.2), spreadRadius: 2)
                                                                                  ]),
                                                                                  child: Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                    children: [
                                                                                      AnimatedContainer(
                                                                                        duration: const Duration(milliseconds: 100),
                                                                                        height: 10,
                                                                                        width: (media.width * 0.9 / double.parse(userDetails['trip_accept_reject_duration_for_driver'].toString())) * (double.parse(userDetails['trip_accept_reject_duration_for_driver'].toString()) - duration),
                                                                                        decoration: BoxDecoration(
                                                                                            color: Colors.green,
                                                                                            borderRadius: (languageDirection == 'ltr')
                                                                                                ? BorderRadius.only(
                                                                                                    topLeft: const Radius.circular(100),
                                                                                                    topRight: (duration <= 2.0) ? const Radius.circular(100) : const Radius.circular(0),
                                                                                                  )
                                                                                                : BorderRadius.only(
                                                                                                    topRight: const Radius.circular(100),
                                                                                                    topLeft: (duration <= 2.0) ? const Radius.circular(100) : const Radius.circular(0),
                                                                                                  )),
                                                                                      ),
                                                                                      Container(
                                                                                        padding: EdgeInsets.fromLTRB(media.width * 0.05, media.width * 0.02, media.width * 0.05, media.width * 0.05),
                                                                                        child: Column(
                                                                                          children: [
                                                                                            Row(
                                                                                              children: [
                                                                                                Container(
                                                                                                  height: media.width * 0.25,
                                                                                                  width: media.width * 0.25,
                                                                                                  decoration: BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: NetworkImage(driverReq['userDetail']['data']['profile_picture']), fit: BoxFit.cover)),
                                                                                                ),
                                                                                                SizedBox(width: media.width * 0.05),
                                                                                                SizedBox(
                                                                                                  height: media.width * 0.2,
                                                                                                  child: Column(
                                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                                                                    children: [
                                                                                                      Text(
                                                                                                        driverReq['userDetail']['data']['name'],
                                                                                                        style: GoogleFonts.roboto(fontSize: media.width * eighteen, color: textColor),
                                                                                                      ),
                                                                                                      Row(
                                                                                                        children: [
                                                                                                          //payment image
                                                                                                          SizedBox(
                                                                                                            width: media.width * 0.06,
                                                                                                            child: (driverReq['payment_opt'].toString() == '1')
                                                                                                                ? Image.asset(
                                                                                                                    'assets/images/cash.png',
                                                                                                                    fit: BoxFit.contain,
                                                                                                                  )
                                                                                                                : (driverReq['payment_opt'].toString() == '2')
                                                                                                                    ? Image.asset('assets/images/wallet.png', fit: BoxFit.contain, color: textColor)
                                                                                                                    : (driverReq['payment_opt'].toString() == '0')
                                                                                                                        ? Image.asset('assets/images/card.png', fit: BoxFit.contain, color: textColor)
                                                                                                                        : Container(),
                                                                                                          ),
                                                                                                          SizedBox(
                                                                                                            width: media.width * 0.03,
                                                                                                          ),
                                                                                                          Text(
                                                                                                            driverReq['payment_type_string'].toString(),
                                                                                                            style: GoogleFonts.roboto(fontSize: media.width * sixteen, color: textColor),
                                                                                                          ),
                                                                                                          SizedBox(width: media.width * 0.03),
                                                                                                          (driverReq['show_request_eta_amount'] == true && driverReq['request_eta_amount'] != null)
                                                                                                              ? SizedBox(
                                                                                                                  width: media.width * 0.2,
                                                                                                                  child: FittedBox(
                                                                                                                    child: Text(
                                                                                                                      userDetails['currency_symbol'] + driverReq['request_eta_amount'].toStringAsFixed(2),
                                                                                                                      style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor),
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                )
                                                                                                              : Container()
                                                                                                        ],
                                                                                                      ),
                                                                                                    ],
                                                                                                  ),
                                                                                                ),
                                                                                                Expanded(
                                                                                                  child: FittedBox(
                                                                                                    child: Text(
                                                                                                      duration.toString().split('.')[0],
                                                                                                      style: GoogleFonts.roboto(fontSize: media.width * twenty, fontWeight: FontWeight.bold, color: textColor),
                                                                                                      textAlign: TextAlign.end,
                                                                                                    ),
                                                                                                  ),
                                                                                                )
                                                                                              ],
                                                                                            ),
                                                                                            SizedBox(
                                                                                              height: media.width * 0.02,
                                                                                            ),
                                                                                            // Icon(Icons.),
                                                                                            SizedBox(
                                                                                              width: media.width * 0.9,
                                                                                              child: Text(
                                                                                                driverReq['goods_type'] + ' - ' + driverReq['goods_type_quantity'],
                                                                                                style: GoogleFonts.roboto(fontSize: media.width * twelve, fontWeight: FontWeight.w600, color: buttonColor),
                                                                                                textAlign: TextAlign.center,
                                                                                                maxLines: 1,
                                                                                                overflow: TextOverflow.ellipsis,
                                                                                              ),
                                                                                            ),
                                                                                            SizedBox(
                                                                                              height: media.width * 0.02,
                                                                                            ),
                                                                                            Row(
                                                                                              children: [
                                                                                                Image.asset(
                                                                                                  'assets/images/picklocation.png',
                                                                                                  width: media.width * 0.075,
                                                                                                ),
                                                                                                SizedBox(width: media.width * 0.05),
                                                                                                SizedBox(
                                                                                                  width: media.width * 0.6,
                                                                                                  child: Text(
                                                                                                    driverReq['pick_address'],
                                                                                                    style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                                    maxLines: 2,
                                                                                                    overflow: TextOverflow.ellipsis,
                                                                                                  ),
                                                                                                )
                                                                                              ],
                                                                                            ),
                                                                                            (driverReq['pickup_poc_instruction'] != null)
                                                                                                ? Container(
                                                                                                    padding: EdgeInsets.only(top: media.width * 0.02),
                                                                                                    child: SizedBox(
                                                                                                      width: media.width * 0.9,
                                                                                                      child: Row(
                                                                                                        mainAxisAlignment: MainAxisAlignment.start,
                                                                                                        children: [
                                                                                                          Text(
                                                                                                            languages[choosenLanguage]['text_instructions'] + ' : ' + driverReq['pickup_poc_instruction'],
                                                                                                            style: GoogleFonts.roboto(fontSize: media.width * twelve, color: buttonColor, fontWeight: FontWeight.w600),
                                                                                                            maxLines: 1,
                                                                                                            overflow: TextOverflow.ellipsis,
                                                                                                          ),
                                                                                                        ],
                                                                                                      ),
                                                                                                    ))
                                                                                                : Container(),
                                                                                            (tripStops.isNotEmpty)
                                                                                                ? Column(
                                                                                                    children: tripStops
                                                                                                        .asMap()
                                                                                                        .map((i, value) {
                                                                                                          return MapEntry(
                                                                                                              i,
                                                                                                              (i < tripStops.length - 1)
                                                                                                                  ? Container(
                                                                                                                      padding: EdgeInsets.only(top: media.width * 0.025),
                                                                                                                      child: Row(
                                                                                                                        children: [
                                                                                                                          SizedBox(
                                                                                                                            width: media.width * 0.075,
                                                                                                                            child: Text(
                                                                                                                              (i + 1).toString(),
                                                                                                                              style: GoogleFonts.roboto(fontSize: media.width * twelve, color: Colors.red),
                                                                                                                              textAlign: TextAlign.center,
                                                                                                                            ),
                                                                                                                          ),
                                                                                                                          SizedBox(width: media.width * 0.05),
                                                                                                                          SizedBox(
                                                                                                                            width: media.width * 0.6,
                                                                                                                            child: Text(
                                                                                                                              tripStops[i]['address'],
                                                                                                                              style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                                                              maxLines: 1,
                                                                                                                              overflow: TextOverflow.ellipsis,
                                                                                                                            ),
                                                                                                                          )
                                                                                                                        ],
                                                                                                                      ),
                                                                                                                    )
                                                                                                                  : Container());
                                                                                                        })
                                                                                                        .values
                                                                                                        .toList(),
                                                                                                  )
                                                                                                : Container(),
                                                                                            SizedBox(
                                                                                              height: media.width * 0.025,
                                                                                            ),
                                                                                            (driverReq['is_rental'] != true)
                                                                                                ? Row(
                                                                                                    children: [
                                                                                                      Icon(
                                                                                                        Icons.location_on_outlined,
                                                                                                        size: media.width * 0.075,
                                                                                                        color: Colors.red,
                                                                                                      ),
                                                                                                      SizedBox(width: media.width * 0.05),
                                                                                                      SizedBox(
                                                                                                        width: media.width * 0.6,
                                                                                                        child: Text(
                                                                                                          driverReq['drop_address'],
                                                                                                          style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                                          maxLines: 2,
                                                                                                          overflow: TextOverflow.ellipsis,
                                                                                                        ),
                                                                                                      )
                                                                                                    ],
                                                                                                  )
                                                                                                : Container(),
                                                                                            SizedBox(
                                                                                              height: media.width * 0.04,
                                                                                            ),
                                                                                            Row(
                                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                              children: [
                                                                                                Button(
                                                                                                    borcolor: buttonColor,
                                                                                                    textcolor: buttonColor,
                                                                                                    width: media.width * 0.38,
                                                                                                    color: page,
                                                                                                    onTap: () async {
                                                                                                      setState(() {
                                                                                                        _isLoading = true;
                                                                                                      });
                                                                                                      //reject request
                                                                                                      var val = await requestReject();
                                                                                                      if (val == 'logout') {
                                                                                                        navigateLogout();
                                                                                                      }
                                                                                                      setState(() {
                                                                                                        _isLoading = false;
                                                                                                      });
                                                                                                    },
                                                                                                    text: languages[choosenLanguage]['text_decline']),
                                                                                                Button(
                                                                                                  onTap: () async {
                                                                                                    setState(() {
                                                                                                      _isLoading = true;
                                                                                                    });
                                                                                                    var val = await requestAccept();
                                                                                                    if (val == 'logout') {
                                                                                                      navigateLogout();
                                                                                                    }
                                                                                                    setState(() {
                                                                                                      _isLoading = false;
                                                                                                    });
                                                                                                  },
                                                                                                  text: languages[choosenLanguage]['text_accept'],
                                                                                                  width: media.width * 0.38,
                                                                                                )
                                                                                              ],
                                                                                            )
                                                                                          ],
                                                                                        ),
                                                                                      )
                                                                                    ],
                                                                                  )),
                                                                            ],
                                                                          )
                                                                        : (driverReq['accepted_at'] !=
                                                                                null)
                                                                            ? SizedBox(
                                                                                width: media.width * 0.9,
                                                                                height: media.width * 0.7,
                                                                              )
                                                                            : Container(width: media.width * 0.9)
                                                                    : Container(
                                                                        width: media.width *
                                                                            0.9,
                                                                      ),
                                                              ],
                                                            )),

                                                        //on ride bottom sheet
                                                        (driverReq['accepted_at'] !=
                                                                null)
                                                            ? Positioned(
                                                                bottom: 0,
                                                                child:
                                                                    GestureDetector(
                                                                  onPanUpdate:
                                                                      (val) {
                                                                    if (val.delta
                                                                            .dy >
                                                                        0) {
                                                                      setState(
                                                                          () {
                                                                        _bottom =
                                                                            0;
                                                                      });
                                                                    }
                                                                    if (val.delta
                                                                            .dy <
                                                                        0) {
                                                                      setState(
                                                                          () {
                                                                        _bottom =
                                                                            1;
                                                                      });
                                                                    }
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    padding: EdgeInsets.all(
                                                                        media.width *
                                                                            0.05),
                                                                    width: media
                                                                            .width *
                                                                        1,
                                                                    decoration: BoxDecoration(
                                                                        borderRadius: const BorderRadius.only(
                                                                            topLeft: Radius.circular(
                                                                                10),
                                                                            topRight: Radius.circular(
                                                                                10)),
                                                                        color:
                                                                            page),
                                                                    child:
                                                                        Column(
                                                                      children: [
                                                                        Container(
                                                                          height:
                                                                              media.width * 0.02,
                                                                          width:
                                                                              media.width * 0.2,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            borderRadius:
                                                                                BorderRadius.circular(media.width * 0.01),
                                                                            color:
                                                                                Colors.grey,
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          height:
                                                                              media.width * 0.025,
                                                                        ),
                                                                        Column(
                                                                            children: [
                                                                              Row(
                                                                                children: [
                                                                                  Container(
                                                                                    height: media.width * 0.25,
                                                                                    width: media.width * 0.25,
                                                                                    decoration: BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: NetworkImage(driverReq['userDetail']['data']['profile_picture']), fit: BoxFit.cover)),
                                                                                  ),
                                                                                  SizedBox(width: media.width * 0.05),
                                                                                  SizedBox(
                                                                                    width: media.width * 0.3,
                                                                                    height: media.width * 0.2,
                                                                                    child: Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                                                      children: [
                                                                                        SizedBox(
                                                                                          width: media.width * 0.3,
                                                                                          child: Text(
                                                                                            driverReq['userDetail']['data']['name'],
                                                                                            style: GoogleFonts.roboto(fontSize: media.width * eighteen, color: textColor),
                                                                                            maxLines: 1,
                                                                                          ),
                                                                                        ),
                                                                                        Row(
                                                                                          children: [
                                                                                            Icon(
                                                                                              Icons.star,
                                                                                              color: buttonColor,
                                                                                              size: media.width * 0.05,
                                                                                            ),
                                                                                            SizedBox(
                                                                                              width: media.width * 0.01,
                                                                                            ),
                                                                                            Text(
                                                                                              driverReq['userDetail']['data']['rating'].toString(),
                                                                                              style: GoogleFonts.roboto(fontSize: media.width * sixteen, color: textColor),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                  Expanded(
                                                                                    child: Row(
                                                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                                                      children: [
                                                                                        (driverReq['accepted_at'] == null && driverReq['show_request_eta_amount'] == true && driverReq['request_eta_amount'] != null)
                                                                                            ? Text(
                                                                                                userDetails['currency_symbol'] + driverReq['request_eta_amount'].toString(),
                                                                                                style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor),
                                                                                              )
                                                                                            : (driverReq['is_driver_arrived'] == 1 && waitingTime != null)
                                                                                                ? (waitingTime / 60 >= 1)
                                                                                                    ? Column(
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                                                        children: [
                                                                                                          Row(
                                                                                                            children: [
                                                                                                              Container(
                                                                                                                width: media.width * 0.25,
                                                                                                                alignment: Alignment.center,
                                                                                                                child: Text(
                                                                                                                  languages[choosenLanguage]['text_waiting_time'],
                                                                                                                  style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: buttonColor),
                                                                                                                ),
                                                                                                              ),
                                                                                                              SizedBox(
                                                                                                                width: media.width * 0.01,
                                                                                                              ),
                                                                                                              InkWell(
                                                                                                                onTap: () {
                                                                                                                  setState(() {
                                                                                                                    _showWaitingInfo = true;
                                                                                                                  });
                                                                                                                },
                                                                                                                child: Icon(
                                                                                                                  Icons.info_outline,
                                                                                                                  size: media.width * 0.04,
                                                                                                                ),
                                                                                                              )
                                                                                                            ],
                                                                                                          ),
                                                                                                          SizedBox(
                                                                                                            height: media.width * 0.02,
                                                                                                          ),
                                                                                                          Container(
                                                                                                            width: media.width * 0.3,
                                                                                                            alignment: Alignment.center,
                                                                                                            child: Text(
                                                                                                              '${(waitingTime / 60).toInt()} mins',
                                                                                                              style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor),
                                                                                                            ),
                                                                                                          ),
                                                                                                        ],
                                                                                                      )
                                                                                                    : Container()
                                                                                                : Container(),
                                                                                      ],
                                                                                    ),
                                                                                  )
                                                                                ],
                                                                              ),
                                                                              SizedBox(
                                                                                height: media.width * 0.05,
                                                                              ),
                                                                              (_bottom != 0)
                                                                                  ? SizedBox(
                                                                                      height: media.height * 0.4,
                                                                                      child: SingleChildScrollView(
                                                                                        physics: const BouncingScrollPhysics(),
                                                                                        child: Column(
                                                                                          children: [
                                                                                            SizedBox(
                                                                                              height: media.width * 0.02,
                                                                                            ),
                                                                                            SizedBox(
                                                                                              width: media.width * 0.9,
                                                                                              child: Text(
                                                                                                driverReq['goods_type'] + ' - ' + driverReq['goods_type_quantity'],
                                                                                                style: GoogleFonts.roboto(fontSize: media.width * fourteen, fontWeight: FontWeight.w600, color: buttonColor),
                                                                                                textAlign: TextAlign.center,
                                                                                                maxLines: 1,
                                                                                                overflow: TextOverflow.ellipsis,
                                                                                              ),
                                                                                            ),
                                                                                            SizedBox(
                                                                                              height: media.width * 0.02,
                                                                                            ),
                                                                                            Row(
                                                                                              children: [
                                                                                                Image.asset(
                                                                                                  'assets/images/picklocation.png',
                                                                                                  width: media.width * 0.075,
                                                                                                ),
                                                                                                SizedBox(width: media.width * 0.05),
                                                                                                SizedBox(
                                                                                                  width: media.width * 0.6,
                                                                                                  child: Text(
                                                                                                    driverReq['pick_address'],
                                                                                                    style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                                    maxLines: 2,
                                                                                                    overflow: TextOverflow.ellipsis,
                                                                                                  ),
                                                                                                )
                                                                                              ],
                                                                                            ),
                                                                                            (driverReq['pickup_poc_instruction'] != null)
                                                                                                ? Container(
                                                                                                    padding: EdgeInsets.only(top: media.width * 0.02),
                                                                                                    child: SizedBox(
                                                                                                      width: media.width * 0.9,
                                                                                                      child: Row(
                                                                                                        mainAxisAlignment: MainAxisAlignment.start,
                                                                                                        children: [
                                                                                                          Text(
                                                                                                            languages[choosenLanguage]['text_instructions'] + ' : ' + driverReq['pickup_poc_instruction'],
                                                                                                            style: GoogleFonts.roboto(fontSize: media.width * twelve, color: buttonColor, fontWeight: FontWeight.w600),
                                                                                                            maxLines: 1,
                                                                                                            overflow: TextOverflow.ellipsis,
                                                                                                          ),
                                                                                                        ],
                                                                                                      ),
                                                                                                    ))
                                                                                                : Container(),
                                                                                            (tripStops.isNotEmpty)
                                                                                                ? Column(
                                                                                                    children: tripStops
                                                                                                        .asMap()
                                                                                                        .map((i, value) {
                                                                                                          return MapEntry(
                                                                                                              i,
                                                                                                              (i < tripStops.length - 1)
                                                                                                                  ? Container(
                                                                                                                      padding: EdgeInsets.only(top: media.width * 0.04),
                                                                                                                      child: Column(
                                                                                                                        children: [
                                                                                                                          Row(
                                                                                                                            children: [
                                                                                                                              SizedBox(
                                                                                                                                width: media.width * 0.075,
                                                                                                                                child: Text(
                                                                                                                                  (i + 1).toString(),
                                                                                                                                  style: GoogleFonts.roboto(fontSize: media.width * twelve, color: Colors.red),
                                                                                                                                  textAlign: TextAlign.center,
                                                                                                                                ),
                                                                                                                              ),
                                                                                                                              SizedBox(width: media.width * 0.05),
                                                                                                                              SizedBox(
                                                                                                                                width: media.width * 0.6,
                                                                                                                                child: Text(
                                                                                                                                  tripStops[i]['address'],
                                                                                                                                  style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),

                                                                                                                                  // maxLines: 1,
                                                                                                                                  overflow: TextOverflow.ellipsis,
                                                                                                                                ),
                                                                                                                              ),
                                                                                                                              SizedBox(width: media.width * 0.05),
                                                                                                                              (driverReq['is_trip_start'] == 1)
                                                                                                                                  ? InkWell(
                                                                                                                                      onTap: () {
                                                                                                                                        makingPhoneCall(tripStops[i]['poc_mobile']);
                                                                                                                                      },
                                                                                                                                      child: Image.asset('assets/images/Call.png', width: media.width * 0.05, color: textColor))
                                                                                                                                  : Container(),
                                                                                                                            ],
                                                                                                                          ),
                                                                                                                          (tripStops[i]['poc_instruction'] != null)
                                                                                                                              ? Container(
                                                                                                                                  padding: EdgeInsets.only(top: media.width * 0.02),
                                                                                                                                  child: Row(
                                                                                                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                                                                                                    children: [
                                                                                                                                      SizedBox(
                                                                                                                                        width: media.width * 0.9,
                                                                                                                                        child: Text(
                                                                                                                                          languages[choosenLanguage]['text_instructions'] + ' : ' + tripStops[i]['poc_instruction'],
                                                                                                                                          style: GoogleFonts.roboto(fontSize: media.width * twelve, color: buttonColor, fontWeight: FontWeight.w600),
                                                                                                                                          // maxLines:1,
                                                                                                                                          // overflow: TextOverflow.ellipsis,
                                                                                                                                        ),
                                                                                                                                      ),
                                                                                                                                    ],
                                                                                                                                  ))
                                                                                                                              : Container(),
                                                                                                                        ],
                                                                                                                      ),
                                                                                                                    )
                                                                                                                  : Container());
                                                                                                        })
                                                                                                        .values
                                                                                                        .toList(),
                                                                                                  )
                                                                                                : Container(),
                                                                                            SizedBox(height: media.width * 0.04),
                                                                                            (driverReq['is_rental'] != true)
                                                                                                ? Row(
                                                                                                    children: [
                                                                                                      Icon(Icons.location_on_outlined, color: Colors.red, size: media.width * 0.075),
                                                                                                      SizedBox(width: media.width * 0.05),
                                                                                                      SizedBox(
                                                                                                        width: media.width * 0.6,
                                                                                                        child: Text(
                                                                                                          driverReq['drop_address'],
                                                                                                          style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                                          maxLines: 2,
                                                                                                          overflow: TextOverflow.ellipsis,
                                                                                                        ),
                                                                                                      ),
                                                                                                      SizedBox(width: media.width * 0.05),
                                                                                                      (driverReq['is_trip_start'] == 1)
                                                                                                          ? InkWell(
                                                                                                              onTap: () {
                                                                                                                makingPhoneCall(driverReq['drop_poc_mobile']);
                                                                                                              },
                                                                                                              child: Image.asset('assets/images/Call.png', width: media.width * 0.05, color: textColor))
                                                                                                          : Container(),
                                                                                                    ],
                                                                                                  )
                                                                                                : Container(),
                                                                                            (driverReq['drop_poc_instruction'] != null)
                                                                                                ? Container(
                                                                                                    padding: EdgeInsets.only(top: media.width * 0.02, bottom: media.width * 0.02),
                                                                                                    child: Row(
                                                                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                                                                      children: [
                                                                                                        SizedBox(
                                                                                                          width: media.width * 0.9,
                                                                                                          child: Text(
                                                                                                            languages[choosenLanguage]['text_instructions'] + ' : ' + driverReq['drop_poc_instruction'],
                                                                                                            style: GoogleFonts.roboto(fontSize: media.width * twelve, color: buttonColor, fontWeight: FontWeight.w600),
                                                                                                            // maxLines:1,
                                                                                                            overflow: TextOverflow.ellipsis,
                                                                                                          ),
                                                                                                        ),
                                                                                                      ],
                                                                                                    ))
                                                                                                : Container(),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                    )
                                                                                  : Container(),
                                                                            ]),
                                                                        (driverReq['is_trip_start'] ==
                                                                                0)
                                                                            ? Column(
                                                                                children: [
                                                                                  (_bottom == 0)
                                                                                      ? Row(
                                                                                          children: [
                                                                                            Icon(Icons.location_on_outlined, color: Colors.red, size: media.width * 0.075),
                                                                                            SizedBox(width: media.width * 0.05),
                                                                                            Column(
                                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                                              children: [
                                                                                                Text(languages[choosenLanguage]['text_pickpoint'], style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor.withOpacity(0.7))),
                                                                                                SizedBox(
                                                                                                  height: media.width * 0.02,
                                                                                                ),
                                                                                                SizedBox(
                                                                                                  width: media.width * 0.6,
                                                                                                  height: media.width * 0.05,
                                                                                                  child: Text(
                                                                                                    driverReq['pick_address'],
                                                                                                    style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                                    maxLines: 1,
                                                                                                    overflow: TextOverflow.ellipsis,
                                                                                                  ),
                                                                                                ),
                                                                                                SizedBox(
                                                                                                  height: media.width * 0.02,
                                                                                                ),
                                                                                              ],
                                                                                            )
                                                                                          ],
                                                                                        )
                                                                                      : Container(),
                                                                                  Row(
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                                                    children: [
                                                                                      Column(
                                                                                        children: [
                                                                                          InkWell(
                                                                                              onTap: () {
                                                                                                makingPhoneCall(driverReq['userDetail']['data']['mobile']);
                                                                                              },
                                                                                              child: Image.asset('assets/images/Call.png', width: media.width * 0.06, color: textColor)),
                                                                                          Text(
                                                                                            languages[choosenLanguage]['text_call'],
                                                                                            style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                          )
                                                                                        ],
                                                                                      ),
                                                                                      (driverReq['if_dispatch'] == true)
                                                                                          ? Container()
                                                                                          : InkWell(
                                                                                              onTap: () {
                                                                                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPage()));
                                                                                              },
                                                                                              child: Column(
                                                                                                children: [
                                                                                                  Row(
                                                                                                    children: [
                                                                                                      Image.asset('assets/images/message-square.png', width: media.width * 0.06, color: textColor),
                                                                                                      (chatList.where((element) => element['from_type'] == 1 && element['seen'] == 0).isNotEmpty)
                                                                                                          ? Text(
                                                                                                              chatList.where((element) => element['from_type'] == 1 && element['seen'] == 0).length.toString(),
                                                                                                              style: GoogleFonts.roboto(fontSize: media.width * twelve, color: const Color(0xffFF0000)),
                                                                                                            )
                                                                                                          : Container()
                                                                                                    ],
                                                                                                  ),
                                                                                                  Text(
                                                                                                    languages[choosenLanguage]['text_chat'],
                                                                                                    style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                                  )
                                                                                                ],
                                                                                              ),
                                                                                            ),
                                                                                      Column(
                                                                                        children: [
                                                                                          InkWell(
                                                                                            onTap: () async {
                                                                                              setState(() {
                                                                                                _isLoading = true;
                                                                                              });
                                                                                              var val = await cancelReason((driverReq['is_driver_arrived'] == 0) ? 'before' : 'after');
                                                                                              if (val == true) {
                                                                                                setState(() {
                                                                                                  _cancelReason = '';
                                                                                                  cancelRequest = true;
                                                                                                  _cancellingError = '';
                                                                                                });
                                                                                              } else if (val == 'logout') {
                                                                                                navigateLogout();
                                                                                              }
                                                                                              setState(() {
                                                                                                _isLoading = false;
                                                                                              });
                                                                                            },
                                                                                            child: Image.asset('assets/images/cancel.png', width: media.width * 0.06, color: textColor),
                                                                                          ),
                                                                                          Text(
                                                                                            languages[choosenLanguage]['text_cancel'],
                                                                                            style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                          )
                                                                                        ],
                                                                                      )
                                                                                    ],
                                                                                  ),
                                                                                ],
                                                                              )
                                                                            : (_bottom == 0 && driverReq['is_trip_start'] == 1 && driverReq['is_rental'] != true)
                                                                                ? Row(
                                                                                    children: [
                                                                                      Icon(Icons.location_on_outlined, color: Colors.red, size: media.width * 0.075),
                                                                                      SizedBox(width: media.width * 0.05),
                                                                                      Column(
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Text(languages[choosenLanguage]['text_droppoint'], style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor.withOpacity(0.7))),
                                                                                          SizedBox(
                                                                                            height: media.width * 0.02,
                                                                                          ),
                                                                                          SizedBox(
                                                                                            width: media.width * 0.6,
                                                                                            height: media.width * 0.05,
                                                                                            child: Text(
                                                                                              driverReq['drop_address'],
                                                                                              style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                                              maxLines: 1,
                                                                                              overflow: TextOverflow.ellipsis,
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      )
                                                                                    ],
                                                                                  )
                                                                                : Container(),
                                                                        SizedBox(
                                                                          height:
                                                                              media.width * 0.05,
                                                                        ),
                                                                        Button(
                                                                            onTap:
                                                                                () async {
                                                                              setState(() {
                                                                                _isLoading = true;
                                                                              });
                                                                              if ((driverReq['is_driver_arrived'] == 0)) {
                                                                                var val = await driverArrived();
                                                                                if (val == 'logout') {
                                                                                  navigateLogout();
                                                                                }
                                                                              } else if (driverReq['is_driver_arrived'] == 1 && driverReq['is_trip_start'] == 0) {
                                                                                if (driverReq['show_otp_feature'] == false && driverReq['enable_shipment_load_feature'].toString() == '0') {
                                                                                  // setState(
                                                                                  //     () {
                                                                                  //   getStartOtp =
                                                                                  //       true;
                                                                                  // });
                                                                                  var val = await tripStartDispatcher();
                                                                                  if (val == 'logout') {
                                                                                    navigateLogout();
                                                                                  }
                                                                                } else {
                                                                                  setState(() {
                                                                                    shipLoadImage = null;
                                                                                    _errorOtp = false;
                                                                                    getStartOtp = true;
                                                                                  });
                                                                                }
                                                                              } else {
                                                                                if (driverReq['enable_shipment_unload_feature'].toString() == '1') {
                                                                                  setState(() {
                                                                                    unloadImage = true;
                                                                                  });
                                                                                } else if (driverReq['enable_shipment_unload_feature'].toString() == '0' && driverReq['enable_digital_signature'].toString() == '1') {
                                                                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DigitalSignature()));
                                                                                } else {
                                                                                  var val = await endTrip();
                                                                                  if (val == 'logout') {
                                                                                    navigateLogout();
                                                                                  }
                                                                                }
                                                                                // Navigator.push(
                                                                                //     context,
                                                                                //     MaterialPageRoute(builder: (context) => const DigitalSignature()));
                                                                                // driverOtp = '';
                                                                                // await endTrip();
                                                                              }

                                                                              _isLoading = false;
                                                                            },
                                                                            text: (driverReq['is_driver_arrived'] == 0)
                                                                                ? languages[choosenLanguage]['text_arrived']
                                                                                : (driverReq['is_driver_arrived'] == 1 && driverReq['is_trip_start'] == 0)
                                                                                    ? languages[choosenLanguage]['text_shipment_load']
                                                                                    : languages[choosenLanguage]['text_shipment_unload'])
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ))
                                                            : Container(),
                                                        if (driverReq.isEmpty)
                                                          Positioned(
                                                            right: 10,
                                                            top: 150,
                                                            child: InkWell(
                                                              onTap: () async {
                                                                if (contactus ==
                                                                    false) {
                                                                  setState(() {
                                                                    contactus =
                                                                        true;
                                                                  });
                                                                } else {
                                                                  setState(() {
                                                                    contactus =
                                                                        false;
                                                                  });
                                                                }
                                                              },
                                                              child: Container(
                                                                height: media
                                                                        .width *
                                                                    0.1,
                                                                width: media
                                                                        .width *
                                                                    0.1,
                                                                decoration: BoxDecoration(
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                          blurRadius:
                                                                              2,
                                                                          color: Colors.black.withOpacity(
                                                                              0.2),
                                                                          spreadRadius:
                                                                              2)
                                                                    ],
                                                                    color: page,
                                                                    borderRadius:
                                                                        BorderRadius.circular(media.width *
                                                                            0.02)),
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                child: Image.asset(
                                                                    'assets/images/customercare.png',
                                                                    fit: BoxFit
                                                                        .contain,
                                                                    width: media
                                                                            .width *
                                                                        0.06,
                                                                    color:
                                                                        textColor),
                                                                // Icon(
                                                                //     Icons
                                                                //         .my_location_sharp,
                                                                //     size: media
                                                                //             .width *
                                                                //         0.06),
                                                              ),
                                                            ),
                                                          ),
                                                        (contactus == true)
                                                            ? Positioned(
                                                                right: 10,
                                                                top: 190,
                                                                child: InkWell(
                                                                  onTap:
                                                                      () async {},
                                                                  child:
                                                                      Container(
                                                                          padding: const EdgeInsets.all(
                                                                              10),
                                                                          height: media.width *
                                                                              0.3,
                                                                          width: media.width *
                                                                              0.45,
                                                                          decoration: BoxDecoration(
                                                                              boxShadow: [
                                                                                BoxShadow(blurRadius: 2, color: Colors.black.withOpacity(0.2), spreadRadius: 2)
                                                                              ],
                                                                              color:
                                                                                  page,
                                                                              borderRadius: BorderRadius.circular(media.width *
                                                                                  0.02)),
                                                                          alignment: Alignment
                                                                              .center,
                                                                          child:
                                                                              Column(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceEvenly,
                                                                            children: [
                                                                              InkWell(
                                                                                onTap: () {
                                                                                  makingPhoneCall(userDetails['contact_us_mobile1']);
                                                                                },
                                                                                child: Row(
                                                                                  children: [
                                                                                    Expanded(flex: 20, child: Icon(Icons.call, color: textColor)),
                                                                                    Expanded(
                                                                                        flex: 80,
                                                                                        child: Text(
                                                                                          userDetails['contact_us_mobile1'].toString(),
                                                                                          style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor),
                                                                                        ))
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                              InkWell(
                                                                                onTap: () {
                                                                                  makingPhoneCall(userDetails['contact_us_mobile1']);
                                                                                },
                                                                                child: Row(
                                                                                  children: [
                                                                                    Expanded(flex: 20, child: Icon(Icons.call, color: textColor)),
                                                                                    Expanded(
                                                                                        flex: 80,
                                                                                        child: Text(
                                                                                          userDetails['contact_us_mobile2'].toString(),
                                                                                          style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor),
                                                                                        ))
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                              InkWell(
                                                                                onTap: () {
                                                                                  openBrowser(userDetails['contact_us_link'].toString());
                                                                                },
                                                                                child: Row(
                                                                                  children: [
                                                                                    Expanded(flex: 20, child: Icon(Icons.vpn_lock_rounded, color: textColor)),
                                                                                    Expanded(
                                                                                        flex: 80,
                                                                                        child: Text(
                                                                                          languages[choosenLanguage]['text_goto_url'],
                                                                                          maxLines: 1,
                                                                                          // overflow:
                                                                                          //     TextOverflow.ellipsis,
                                                                                          style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor),
                                                                                        ))
                                                                                  ],
                                                                                ),
                                                                              )
                                                                            ],
                                                                          )),
                                                                ),
                                                              )
                                                            : Container(),
                                                        //user cancelled request popup
                                                        (_reqCancelled == true)
                                                            ? Positioned(
                                                                bottom: media
                                                                        .height *
                                                                    0.5,
                                                                child:
                                                                    Container(
                                                                  padding: EdgeInsets
                                                                      .all(media
                                                                              .width *
                                                                          0.05),
                                                                  decoration: BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(10),
                                                                      color: page,
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                            color: Colors.black.withOpacity(
                                                                                0.2),
                                                                            blurRadius:
                                                                                2,
                                                                            spreadRadius:
                                                                                2)
                                                                      ]),
                                                                  child: Text(languages[
                                                                          choosenLanguage]
                                                                      [
                                                                      'text_user_cancelled_request']),
                                                                ))
                                                            : Container(),
                                                      ],
                                                    )
                                                  : Container(),
                                    ]),
                              ),
                              (_locationDenied == true)
                                  ? Positioned(
                                      child: Container(
                                      height: media.height * 1,
                                      width: media.width * 1,
                                      color:
                                          Colors.transparent.withOpacity(0.6),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: media.width * 0.9,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _locationDenied = false;
                                                    });
                                                  },
                                                  child: Container(
                                                    height: media.height * 0.05,
                                                    width: media.height * 0.05,
                                                    decoration: BoxDecoration(
                                                      color: page,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(Icons.cancel,
                                                        color: buttonColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: media.width * 0.025),
                                          Container(
                                            padding: EdgeInsets.all(
                                                media.width * 0.05),
                                            width: media.width * 0.9,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: page,
                                                boxShadow: [
                                                  BoxShadow(
                                                      blurRadius: 2.0,
                                                      spreadRadius: 2.0,
                                                      color: Colors.black
                                                          .withOpacity(0.2))
                                                ]),
                                            child: Column(
                                              children: [
                                                SizedBox(
                                                    width: media.width * 0.8,
                                                    child: Text(
                                                      languages[choosenLanguage]
                                                          [
                                                          'text_open_loc_settings'],
                                                      style: GoogleFonts.roboto(
                                                          fontSize:
                                                              media.width *
                                                                  sixteen,
                                                          color: textColor,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    )),
                                                SizedBox(
                                                    height: media.width * 0.05),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    InkWell(
                                                        onTap: () async {
                                                          await perm
                                                              .openAppSettings();
                                                        },
                                                        child: Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              [
                                                              'text_open_settings'],
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      sixteen,
                                                              color:
                                                                  buttonColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        )),
                                                    InkWell(
                                                        onTap: () async {
                                                          setState(() {
                                                            _locationDenied =
                                                                false;
                                                            _isLoading = true;
                                                          });

                                                          getLocs();
                                                        },
                                                        child: Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              ['text_done'],
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      sixteen,
                                                              color:
                                                                  buttonColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ))
                                                  ],
                                                )
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ))
                                  : Container(),
                              //enter otp
                              (getStartOtp == true &&
                                      driverReq.isNotEmpty &&
                                      driverReq['enable_shipment_load_feature']
                                              .toString() ==
                                          '1')
                                  ? Positioned(
                                      top: 0,
                                      child: Container(
                                        height: media.height * 1,
                                        width: media.width * 1,
                                        padding: EdgeInsets.fromLTRB(
                                            media.width * 0.1,
                                            MediaQuery.of(context).padding.top +
                                                media.width * 0.05,
                                            media.width * 0.1,
                                            media.width * 0.05),
                                        color: page,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: media.width * 0.8,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        getStartOtp = false;
                                                      });
                                                    },
                                                    child: Container(
                                                      height:
                                                          media.height * 0.05,
                                                      width:
                                                          media.height * 0.05,
                                                      decoration: BoxDecoration(
                                                        color: page,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(Icons.cancel,
                                                          color: buttonColor),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                                height: media.width * 0.025),
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  children: [
                                                    (driverReq['show_otp_feature'] ==
                                                            true)
                                                        ? Column(children: [
                                                            Text(
                                                              languages[
                                                                      choosenLanguage]
                                                                  [
                                                                  'text_driver_otp'],
                                                              style: GoogleFonts.roboto(
                                                                  fontSize: media
                                                                          .width *
                                                                      eighteen,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      textColor),
                                                            ),
                                                            SizedBox(
                                                                height: media
                                                                        .width *
                                                                    0.05),
                                                            Text(
                                                              languages[
                                                                      choosenLanguage]
                                                                  [
                                                                  'text_enterdriverotp'],
                                                              style: GoogleFonts
                                                                  .roboto(
                                                                fontSize: media
                                                                        .width *
                                                                    twelve,
                                                                color: textColor
                                                                    .withOpacity(
                                                                        0.7),
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                            SizedBox(
                                                              height:
                                                                  media.width *
                                                                      0.05,
                                                            ),
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceAround,
                                                              children: [
                                                                Container(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  width: media
                                                                          .width *
                                                                      0.12,
                                                                  color: page,
                                                                  child:
                                                                      TextFormField(
                                                                    onChanged:
                                                                        (val) {
                                                                      if (val.length ==
                                                                          1) {
                                                                        setState(
                                                                            () {
                                                                          _otp1 =
                                                                              val;
                                                                          driverOtp = _otp1 +
                                                                              _otp2 +
                                                                              _otp3 +
                                                                              _otp4;
                                                                          FocusScope.of(context)
                                                                              .nextFocus();
                                                                        });
                                                                      }
                                                                    },
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .number,
                                                                    maxLength:
                                                                        1,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    decoration: InputDecoration(
                                                                        counterText:
                                                                            '',
                                                                        border: const UnderlineInputBorder(
                                                                            borderSide: BorderSide(
                                                                                color: Colors.black,
                                                                                width: 1.5,
                                                                                style: BorderStyle.solid)),
                                                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: (isDarkTheme == true) ? Colors.white : hintColor))),
                                                                    style: GoogleFonts
                                                                        .roboto(
                                                                            color:
                                                                                textColor),
                                                                  ),
                                                                ),
                                                                Container(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  width: media
                                                                          .width *
                                                                      0.12,
                                                                  color: page,
                                                                  child:
                                                                      TextFormField(
                                                                    onChanged:
                                                                        (val) {
                                                                      if (val.length ==
                                                                          1) {
                                                                        setState(
                                                                            () {
                                                                          _otp2 =
                                                                              val;
                                                                          driverOtp = _otp1 +
                                                                              _otp2 +
                                                                              _otp3 +
                                                                              _otp4;
                                                                          FocusScope.of(context)
                                                                              .nextFocus();
                                                                        });
                                                                      } else {
                                                                        setState(
                                                                            () {
                                                                          _otp2 =
                                                                              val;
                                                                          driverOtp = _otp1 +
                                                                              _otp2 +
                                                                              _otp3 +
                                                                              _otp4;
                                                                          FocusScope.of(context)
                                                                              .previousFocus();
                                                                        });
                                                                      }
                                                                    },
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .number,
                                                                    maxLength:
                                                                        1,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    decoration: InputDecoration(
                                                                        counterText:
                                                                            '',
                                                                        border: const UnderlineInputBorder(
                                                                            borderSide: BorderSide(
                                                                                color: Colors.black,
                                                                                width: 1.5,
                                                                                style: BorderStyle.solid)),
                                                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: (isDarkTheme == true) ? Colors.white : hintColor))),
                                                                    style: GoogleFonts
                                                                        .roboto(
                                                                            color:
                                                                                textColor),
                                                                  ),
                                                                ),
                                                                Container(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  width: media
                                                                          .width *
                                                                      0.12,
                                                                  color: page,
                                                                  child:
                                                                      TextFormField(
                                                                    onChanged:
                                                                        (val) {
                                                                      if (val.length ==
                                                                          1) {
                                                                        setState(
                                                                            () {
                                                                          _otp3 =
                                                                              val;
                                                                          driverOtp = _otp1 +
                                                                              _otp2 +
                                                                              _otp3 +
                                                                              _otp4;
                                                                          FocusScope.of(context)
                                                                              .nextFocus();
                                                                        });
                                                                      } else {
                                                                        setState(
                                                                            () {
                                                                          _otp3 =
                                                                              val;
                                                                          driverOtp = _otp1 +
                                                                              _otp2 +
                                                                              _otp3 +
                                                                              _otp4;
                                                                          FocusScope.of(context)
                                                                              .previousFocus();
                                                                        });
                                                                      }
                                                                    },
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .number,
                                                                    maxLength:
                                                                        1,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    decoration: InputDecoration(
                                                                        counterText:
                                                                            '',
                                                                        border: const UnderlineInputBorder(
                                                                            borderSide: BorderSide(
                                                                                color: Colors.black,
                                                                                width: 1.5,
                                                                                style: BorderStyle.solid)),
                                                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: (isDarkTheme == true) ? Colors.white : hintColor))),
                                                                    style: GoogleFonts
                                                                        .roboto(
                                                                            color:
                                                                                textColor),
                                                                  ),
                                                                ),
                                                                Container(
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  width: media
                                                                          .width *
                                                                      0.12,
                                                                  color: page,
                                                                  child:
                                                                      TextFormField(
                                                                    onChanged:
                                                                        (val) {
                                                                      if (val.length ==
                                                                          1) {
                                                                        setState(
                                                                            () {
                                                                          _otp4 =
                                                                              val;
                                                                          driverOtp = _otp1 +
                                                                              _otp2 +
                                                                              _otp3 +
                                                                              _otp4;
                                                                          FocusScope.of(context)
                                                                              .nextFocus();
                                                                        });
                                                                      } else {
                                                                        setState(
                                                                            () {
                                                                          _otp4 =
                                                                              val;
                                                                          driverOtp = _otp1 +
                                                                              _otp2 +
                                                                              _otp3 +
                                                                              _otp4;
                                                                          FocusScope.of(context)
                                                                              .previousFocus();
                                                                        });
                                                                      }
                                                                    },
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .number,
                                                                    maxLength:
                                                                        1,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    decoration: InputDecoration(
                                                                        counterText:
                                                                            '',
                                                                        border: const UnderlineInputBorder(
                                                                            borderSide: BorderSide(
                                                                                color: Colors.black,
                                                                                width: 1.5,
                                                                                style: BorderStyle.solid)),
                                                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: (isDarkTheme == true) ? Colors.white : hintColor))),
                                                                    style: GoogleFonts
                                                                        .roboto(
                                                                            color:
                                                                                textColor),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            SizedBox(
                                                              height:
                                                                  media.width *
                                                                      0.04,
                                                            ),
                                                            (_errorOtp == true)
                                                                ? Text(
                                                                    languages[
                                                                            choosenLanguage]
                                                                        [
                                                                        'text_error_trip_otp'],
                                                                    style: GoogleFonts.roboto(
                                                                        color: Colors
                                                                            .red,
                                                                        fontSize:
                                                                            media.width *
                                                                                twelve),
                                                                  )
                                                                : Container(),
                                                            SizedBox(
                                                                height: media
                                                                        .width *
                                                                    0.02),
                                                          ])
                                                        : Container(),
                                                    SizedBox(
                                                      width: media.width * 0.8,
                                                      child: Text(
                                                        languages[
                                                                choosenLanguage]
                                                            [
                                                            'text_shipment_title'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                          fontSize:
                                                              media.width *
                                                                  eighteen,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: textColor,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        height:
                                                            media.width * 0.02),
                                                    Container(
                                                        height:
                                                            media.width * 0.5,
                                                        width:
                                                            media.width * 0.5,
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                              color:
                                                                  borderLines,
                                                              width: 1.1),
                                                        ),
                                                        child:
                                                            (shipLoadImage ==
                                                                    null)
                                                                ? InkWell(
                                                                    onTap: () {
                                                                      pickImageFromCamera(
                                                                          1);
                                                                    },
                                                                    child:
                                                                        Center(
                                                                      child: Text(
                                                                          languages[choosenLanguage]
                                                                              [
                                                                              'text_add_shipmentimage'],
                                                                          style: GoogleFonts.roboto(
                                                                              fontSize: media.width * twelve,
                                                                              color: (isDarkTheme == true) ? textColor.withOpacity(0.4) : hintColor),
                                                                          textAlign: TextAlign.center),
                                                                    ),
                                                                  )
                                                                : InkWell(
                                                                    onTap: () {
                                                                      pickImageFromCamera(
                                                                          1);
                                                                    },
                                                                    child:
                                                                        Container(
                                                                      height:
                                                                          media.width *
                                                                              0.5,
                                                                      width: media
                                                                              .width *
                                                                          0.5,
                                                                      decoration: BoxDecoration(

                                                                          // color: Colors.transparent.withOpacity(0.4),
                                                                          image: DecorationImage(image: FileImage(File(shipLoadImage)), fit: BoxFit.contain, colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.5), BlendMode.dstATop))),
                                                                      child: Center(
                                                                          child: Text(
                                                                              languages[choosenLanguage]['text_edit_shipmentimage'],
                                                                              style: GoogleFonts.roboto(fontSize: media.width * twelve, color: textColor),
                                                                              textAlign: TextAlign.center)),
                                                                    ),
                                                                  )

                                                        // Image.file(File(shipLoadImage),height: media.width*0.5,width: media.width*0.5,fit: BoxFit.contain,)
                                                        ),
                                                    SizedBox(
                                                      height:
                                                          media.width * 0.05,
                                                    ),
                                                    (beforeImageUploadError !=
                                                            '')
                                                        ? SizedBox(
                                                            width: media.width *
                                                                0.9,
                                                            child: Text(
                                                                beforeImageUploadError,
                                                                style: GoogleFonts.roboto(
                                                                    fontSize: media
                                                                            .width *
                                                                        sixteen,
                                                                    color: Colors
                                                                        .red),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center),
                                                          )
                                                        : Container()
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                                height: media.width * 0.02),
                                            Button(
                                              onTap: () async {
                                                if (driverReq[
                                                        'show_otp_feature'] ==
                                                    true) {
                                                  if (driverOtp.length != 4 ||
                                                      shipLoadImage == null) {
                                                    setState(() {});
                                                  } else {
                                                    setState(() {
                                                      _errorOtp = false;
                                                      beforeImageUploadError =
                                                          '';
                                                      _isLoading = true;
                                                    });
                                                    var upload =
                                                        await uploadLoadingImage(
                                                            shipLoadImage);
                                                    if (upload == 'success') {
                                                      var val =
                                                          await tripStart();
                                                      if (val == 'logout') {
                                                        navigateLogout();
                                                      } else if (val !=
                                                          'success') {
                                                        setState(() {
                                                          _errorOtp = true;
                                                          _isLoading = false;
                                                        });
                                                      } else {
                                                        setState(() {
                                                          _isLoading = false;
                                                          getStartOtp = false;
                                                        });
                                                      }
                                                    } else if (upload ==
                                                        'logout') {
                                                      navigateLogout();
                                                    } else {
                                                      setState(() {
                                                        beforeImageUploadError =
                                                            languages[
                                                                    choosenLanguage]
                                                                [
                                                                'text_somethingwentwrong'];
                                                        _isLoading = false;
                                                      });
                                                    }
                                                  }
                                                } else {
                                                  if (shipLoadImage == null) {
                                                    setState(() {});
                                                  } else {
                                                    setState(() {
                                                      _errorOtp = false;
                                                      beforeImageUploadError =
                                                          '';
                                                      _isLoading = true;
                                                    });
                                                    var upload =
                                                        await uploadLoadingImage(
                                                            shipLoadImage);
                                                    if (upload == 'success') {
                                                      var val =
                                                          await tripStartDispatcher();
                                                      if (val == 'logout') {
                                                        navigateLogout();
                                                      } else if (val !=
                                                          'success') {
                                                        setState(() {
                                                          _errorOtp = true;
                                                          _isLoading = false;
                                                        });
                                                      } else {
                                                        setState(() {
                                                          _isLoading = false;
                                                          getStartOtp = false;
                                                        });
                                                      }
                                                    } else if (upload ==
                                                        'logout') {
                                                      navigateLogout();
                                                    } else {
                                                      setState(() {
                                                        beforeImageUploadError =
                                                            languages[
                                                                    choosenLanguage]
                                                                [
                                                                'text_somethingwentwrong'];
                                                        _isLoading = false;
                                                      });
                                                    }
                                                  }
                                                }
                                              },
                                              text: languages[choosenLanguage]
                                                  ['text_confirm'],
                                              color: (driverReq[
                                                          'show_otp_feature'] ==
                                                      true)
                                                  ? (driverOtp.length != 4 ||
                                                          shipLoadImage == null)
                                                      ? Colors.grey
                                                      : buttonColor
                                                  : (shipLoadImage == null)
                                                      ? Colors.grey
                                                      : buttonColor,
                                              borcolor: (driverReq[
                                                          'show_otp_feature'] ==
                                                      true)
                                                  ? (driverOtp.length != 4 ||
                                                          shipLoadImage == null)
                                                      ? Colors.grey
                                                      : buttonColor
                                                  : (shipLoadImage == null)
                                                      ? Colors.grey
                                                      : buttonColor,
                                            )
                                          ],
                                        ),
                                      ),
                                    )
                                  : (getStartOtp == true &&
                                          driverReq.isNotEmpty)
                                      ? Positioned(
                                          top: 0,
                                          child: Container(
                                            height: media.height * 1,
                                            width: media.width * 1,
                                            color: Colors.transparent
                                                .withOpacity(0.5),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: media.width * 0.8,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          setState(() {
                                                            getStartOtp = false;
                                                          });
                                                        },
                                                        child: Container(
                                                          height: media.height *
                                                              0.05,
                                                          width: media.height *
                                                              0.05,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: page,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: Icon(
                                                              Icons.cancel,
                                                              color:
                                                                  buttonColor),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                    height:
                                                        media.width * 0.025),
                                                Container(
                                                  padding: EdgeInsets.all(
                                                      media.width * 0.05),
                                                  width: media.width * 0.8,
                                                  height: media.width * 0.7,
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      color: page,
                                                      boxShadow: [
                                                        BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.2),
                                                            spreadRadius: 2,
                                                            blurRadius: 2)
                                                      ]),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        languages[
                                                                choosenLanguage]
                                                            ['text_driver_otp'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                                fontSize: media
                                                                        .width *
                                                                    eighteen,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    textColor),
                                                      ),
                                                      SizedBox(
                                                          height: media.width *
                                                              0.05),
                                                      Text(
                                                        languages[
                                                                choosenLanguage]
                                                            [
                                                            'text_enterdriverotp'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                          fontSize:
                                                              media.width *
                                                                  twelve,
                                                          color: textColor
                                                              .withOpacity(0.7),
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            media.width * 0.05,
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceAround,
                                                        children: [
                                                          Container(
                                                            alignment: Alignment
                                                                .center,
                                                            width: media.width *
                                                                0.12,
                                                            color: page,
                                                            child:
                                                                TextFormField(
                                                              onChanged: (val) {
                                                                if (val.length ==
                                                                    1) {
                                                                  setState(() {
                                                                    _otp1 = val;
                                                                    driverOtp = _otp1 +
                                                                        _otp2 +
                                                                        _otp3 +
                                                                        _otp4;
                                                                    FocusScope.of(
                                                                            context)
                                                                        .nextFocus();
                                                                  });
                                                                }
                                                              },
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              maxLength: 1,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              decoration: const InputDecoration(
                                                                  counterText:
                                                                      '',
                                                                  border: UnderlineInputBorder(
                                                                      borderSide: BorderSide(
                                                                          color: Colors
                                                                              .black,
                                                                          width:
                                                                              1.5,
                                                                          style:
                                                                              BorderStyle.solid))),
                                                            ),
                                                          ),
                                                          Container(
                                                            alignment: Alignment
                                                                .center,
                                                            width: media.width *
                                                                0.12,
                                                            color: page,
                                                            child:
                                                                TextFormField(
                                                              onChanged: (val) {
                                                                if (val.length ==
                                                                    1) {
                                                                  setState(() {
                                                                    _otp2 = val;
                                                                    driverOtp = _otp1 +
                                                                        _otp2 +
                                                                        _otp3 +
                                                                        _otp4;
                                                                    FocusScope.of(
                                                                            context)
                                                                        .nextFocus();
                                                                  });
                                                                } else {
                                                                  setState(() {
                                                                    FocusScope.of(
                                                                            context)
                                                                        .previousFocus();
                                                                  });
                                                                }
                                                              },
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              maxLength: 1,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              decoration: const InputDecoration(
                                                                  counterText:
                                                                      '',
                                                                  border: UnderlineInputBorder(
                                                                      borderSide: BorderSide(
                                                                          color: Colors
                                                                              .black,
                                                                          width:
                                                                              1.5,
                                                                          style:
                                                                              BorderStyle.solid))),
                                                            ),
                                                          ),
                                                          Container(
                                                            alignment: Alignment
                                                                .center,
                                                            width: media.width *
                                                                0.12,
                                                            color: page,
                                                            child:
                                                                TextFormField(
                                                              onChanged: (val) {
                                                                if (val.length ==
                                                                    1) {
                                                                  setState(() {
                                                                    _otp3 = val;
                                                                    driverOtp = _otp1 +
                                                                        _otp2 +
                                                                        _otp3 +
                                                                        _otp4;
                                                                    FocusScope.of(
                                                                            context)
                                                                        .nextFocus();
                                                                  });
                                                                } else {
                                                                  setState(() {
                                                                    FocusScope.of(
                                                                            context)
                                                                        .previousFocus();
                                                                  });
                                                                }
                                                              },
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              maxLength: 1,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              decoration: const InputDecoration(
                                                                  counterText:
                                                                      '',
                                                                  border: UnderlineInputBorder(
                                                                      borderSide: BorderSide(
                                                                          color: Colors
                                                                              .black,
                                                                          width:
                                                                              1.5,
                                                                          style:
                                                                              BorderStyle.solid))),
                                                            ),
                                                          ),
                                                          Container(
                                                            alignment: Alignment
                                                                .center,
                                                            width: media.width *
                                                                0.12,
                                                            color: page,
                                                            child:
                                                                TextFormField(
                                                              onChanged: (val) {
                                                                if (val.length ==
                                                                    1) {
                                                                  setState(() {
                                                                    _otp4 = val;
                                                                    driverOtp = _otp1 +
                                                                        _otp2 +
                                                                        _otp3 +
                                                                        _otp4;
                                                                    FocusScope.of(
                                                                            context)
                                                                        .nextFocus();
                                                                  });
                                                                } else {
                                                                  setState(() {
                                                                    FocusScope.of(
                                                                            context)
                                                                        .previousFocus();
                                                                  });
                                                                }
                                                              },
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              maxLength: 1,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              decoration: const InputDecoration(
                                                                  counterText:
                                                                      '',
                                                                  border: UnderlineInputBorder(
                                                                      borderSide: BorderSide(
                                                                          color: Colors
                                                                              .black,
                                                                          width:
                                                                              1.5,
                                                                          style:
                                                                              BorderStyle.solid))),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            media.width * 0.04,
                                                      ),
                                                      (_errorOtp == true)
                                                          ? Text(
                                                              languages[
                                                                      choosenLanguage]
                                                                  [
                                                                  'text_error_trip_otp'],
                                                              style: GoogleFonts.roboto(
                                                                  color: Colors
                                                                      .red,
                                                                  fontSize: media
                                                                          .width *
                                                                      twelve),
                                                            )
                                                          : Container(),
                                                      SizedBox(
                                                          height: media.width *
                                                              0.02),
                                                      Button(
                                                        onTap: () async {
                                                          if (driverOtp
                                                                  .length !=
                                                              4) {
                                                            setState(() {});
                                                          } else {
                                                            setState(() {
                                                              _errorOtp = false;
                                                              _isLoading = true;
                                                            });
                                                            var val =
                                                                await tripStart();
                                                            if (val ==
                                                                'logout') {
                                                              navigateLogout();
                                                            } else if (val !=
                                                                'success') {
                                                              setState(() {
                                                                _errorOtp =
                                                                    true;
                                                                _isLoading =
                                                                    false;
                                                              });
                                                            } else {
                                                              setState(() {
                                                                _isLoading =
                                                                    false;
                                                                getStartOtp =
                                                                    false;
                                                              });
                                                            }
                                                          }
                                                        },
                                                        text: languages[
                                                                choosenLanguage]
                                                            ['text_confirm'],
                                                        color:
                                                            (driverOtp.length !=
                                                                    4)
                                                                ? Colors.grey
                                                                : buttonColor,
                                                        borcolor:
                                                            (driverOtp.length !=
                                                                    4)
                                                                ? Colors.grey
                                                                : buttonColor,
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Container(),

                              //shipment unload image
                              (unloadImage == true)
                                  ? Positioned(
                                      child: Container(
                                      height: media.height,
                                      width: media.width * 1,
                                      color: page,
                                      padding: EdgeInsets.fromLTRB(
                                          media.width * 0.05,
                                          MediaQuery.of(context).padding.top +
                                              media.width * 0.05,
                                          media.width * 0.05,
                                          media.width * 0.05),
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: media.width * 0.8,
                                            child: Stack(
                                              children: [
                                                Container(
                                                    padding: EdgeInsets.only(
                                                        left:
                                                            media.width * 0.05,
                                                        right:
                                                            media.width * 0.05),
                                                    alignment: Alignment.center,
                                                    // color:Colors.red,
                                                    height: media.width * 0.15,
                                                    width: media.width * 0.9,
                                                    child: Text(
                                                      languages[choosenLanguage]
                                                          ['text_unload_title'],
                                                      style: GoogleFonts.roboto(
                                                          color: textColor,
                                                          fontSize:
                                                              media.width *
                                                                  eighteen),
                                                      maxLines: 1,
                                                      textAlign:
                                                          TextAlign.center,
                                                    )),
                                                Positioned(
                                                  right: 0,
                                                  top: media.width * 0.025,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        unloadImage = false;
                                                      });
                                                    },
                                                    child: Container(
                                                      height: media.width * 0.1,
                                                      width: media.width * 0.1,
                                                      decoration: BoxDecoration(
                                                        color: page,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(Icons.cancel,
                                                          color: buttonColor),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            height: media.width * 0.05,
                                          ),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  Container(
                                                    height: media.width * 0.5,
                                                    width: media.width * 0.5,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: borderLines,
                                                          width: 1.1),
                                                    ),
                                                    child:
                                                        (shipUnloadImage ==
                                                                null)
                                                            ? InkWell(
                                                                onTap: () {
                                                                  pickImageFromCamera(
                                                                      2);
                                                                },
                                                                child: Center(
                                                                  child: Text(
                                                                      languages[
                                                                              choosenLanguage]
                                                                          [
                                                                          'text_add_unloadImage'],
                                                                      style: GoogleFonts.roboto(
                                                                          fontSize: media.width *
                                                                              twelve,
                                                                          color: (isDarkTheme == true)
                                                                              ? textColor.withOpacity(
                                                                                  0.4)
                                                                              : hintColor),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center),
                                                                ),
                                                              )
                                                            : InkWell(
                                                                onTap: () {
                                                                  pickImageFromCamera(
                                                                      2);
                                                                },
                                                                child:
                                                                    Container(
                                                                  height: media
                                                                          .width *
                                                                      0.5,
                                                                  width: media
                                                                          .width *
                                                                      0.5,
                                                                  decoration:
                                                                      BoxDecoration(

                                                                          // color: Colors.transparent.withOpacity(0.4),
                                                                          image: DecorationImage(
                                                                              image: FileImage(File(shipUnloadImage)),
                                                                              fit: BoxFit.contain,
                                                                              colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.5), BlendMode.dstATop))),
                                                                  child: Center(
                                                                      child: Text(
                                                                          languages[choosenLanguage]
                                                                              [
                                                                              'text_edit_unloadimage'],
                                                                          style: GoogleFonts.roboto(
                                                                              fontSize: media.width *
                                                                                  twelve,
                                                                              color:
                                                                                  textColor),
                                                                          textAlign:
                                                                              TextAlign.center)),
                                                                ),
                                                              ),

                                                    // Image.file(File(shipLoadImage),height: media.width*0.5,width: media.width*0.5,fit: BoxFit.contain,)
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          media.width * 0.05),
                                                  (afterImageUploadError != '')
                                                      ? SizedBox(
                                                          width:
                                                              media.width * 0.9,
                                                          child: Text(
                                                              afterImageUploadError,
                                                              style: GoogleFonts.roboto(
                                                                  fontSize: media
                                                                          .width *
                                                                      sixteen,
                                                                  color: Colors
                                                                      .red),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center),
                                                        )
                                                      : Container()
                                                ],
                                              ),
                                            ),
                                          ),
                                          (shipUnloadImage != null)
                                              ? Button(
                                                  onTap: () async {
                                                    setState(() {
                                                      _isLoading = true;
                                                      afterImageUploadError =
                                                          '';
                                                    });
                                                    var val =
                                                        await uploadUnloadingImage(
                                                            shipUnloadImage);
                                                    if (val == 'success') {
                                                      if (driverReq[
                                                                  'enable_digital_signature']
                                                              .toString() ==
                                                          '1') {
                                                        navigate();
                                                      } else {
                                                        var val =
                                                            await endTrip();
                                                        if (val == 'logout') {
                                                          navigateLogout();
                                                        }
                                                      }
                                                    } else if (val ==
                                                        'logout') {
                                                      navigateLogout();
                                                    } else {
                                                      setState(() {
                                                        afterImageUploadError =
                                                            languages[
                                                                    choosenLanguage]
                                                                [
                                                                'text_somethingwentwrong'];
                                                      });
                                                    }
                                                    setState(() {
                                                      _isLoading = false;
                                                    });
                                                  },
                                                  text: 'Upload')
                                              : Container()
                                        ],
                                      ),
                                    ))
                                  : Container(),

                              //permission denied popup
                              (_permission != '')
                                  ? Positioned(
                                      child: Container(
                                      height: media.height * 1,
                                      width: media.width * 1,
                                      color:
                                          Colors.transparent.withOpacity(0.6),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: media.width * 0.9,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _permission = '';
                                                    });
                                                  },
                                                  child: Container(
                                                    height: media.width * 0.1,
                                                    width: media.width * 0.1,
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: page),
                                                    child: const Icon(
                                                        Icons.cancel_outlined),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            height: media.width * 0.05,
                                          ),
                                          Container(
                                            padding: EdgeInsets.all(
                                                media.width * 0.05),
                                            width: media.width * 0.9,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                color: page,
                                                boxShadow: [
                                                  BoxShadow(
                                                      blurRadius: 2.0,
                                                      spreadRadius: 2.0,
                                                      color: Colors.black
                                                          .withOpacity(0.2))
                                                ]),
                                            child: Column(
                                              children: [
                                                SizedBox(
                                                    width: media.width * 0.8,
                                                    child: Text(
                                                      languages[choosenLanguage]
                                                          [
                                                          'text_open_camera_setting'],
                                                      style: GoogleFonts.roboto(
                                                          fontSize:
                                                              media.width *
                                                                  sixteen,
                                                          color: textColor,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    )),
                                                SizedBox(
                                                    height: media.width * 0.05),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    InkWell(
                                                        onTap: () async {
                                                          await perm
                                                              .openAppSettings();
                                                        },
                                                        child: Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              [
                                                              'text_open_settings'],
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      sixteen,
                                                              color:
                                                                  buttonColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        )),
                                                    InkWell(
                                                        onTap: () async {
                                                          // pickImageFromCamera();
                                                          setState(() {
                                                            _permission = '';
                                                          });
                                                        },
                                                        child: Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              ['text_done'],
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      sixteen,
                                                              color:
                                                                  buttonColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ))
                                                  ],
                                                )
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ))
                                  : Container(),

                              //popup for cancel request
                              (cancelRequest == true && driverReq.isNotEmpty)
                                  ? Positioned(
                                      child: Container(
                                      height: media.height * 1,
                                      width: media.width * 1,
                                      color:
                                          Colors.transparent.withOpacity(0.6),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(
                                                media.width * 0.05),
                                            width: media.width * 0.9,
                                            decoration: BoxDecoration(
                                                color: page,
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Column(children: [
                                              Container(
                                                height: media.width * 0.18,
                                                width: media.width * 0.18,
                                                decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Color(0xffFEF2F2)),
                                                alignment: Alignment.center,
                                                child: Container(
                                                  height: media.width * 0.14,
                                                  width: media.width * 0.14,
                                                  decoration:
                                                      const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: Color(
                                                              0xffFF0000)),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.cancel_outlined,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                children: cancelReasonsList
                                                    .asMap()
                                                    .map((i, value) {
                                                      return MapEntry(
                                                          i,
                                                          InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                _cancelReason =
                                                                    cancelReasonsList[
                                                                            i][
                                                                        'reason'];
                                                              });
                                                            },
                                                            child: Container(
                                                              padding: EdgeInsets
                                                                  .all(media
                                                                          .width *
                                                                      0.01),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    height: media
                                                                            .height *
                                                                        0.05,
                                                                    width: media
                                                                            .width *
                                                                        0.05,
                                                                    decoration: BoxDecoration(
                                                                        shape: BoxShape
                                                                            .circle,
                                                                        border: Border.all(
                                                                            color:
                                                                                textColor,
                                                                            width:
                                                                                1.2)),
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    child: (_cancelReason ==
                                                                            cancelReasonsList[i]['reason'])
                                                                        ? Container(
                                                                            height:
                                                                                media.width * 0.03,
                                                                            width:
                                                                                media.width * 0.03,
                                                                            decoration:
                                                                                BoxDecoration(
                                                                              shape: BoxShape.circle,
                                                                              color: textColor,
                                                                            ),
                                                                          )
                                                                        : Container(),
                                                                  ),
                                                                  SizedBox(
                                                                    width: media
                                                                            .width *
                                                                        0.05,
                                                                  ),
                                                                  SizedBox(
                                                                    width: media
                                                                            .width *
                                                                        0.65,
                                                                    child: Text(
                                                                      cancelReasonsList[
                                                                              i]
                                                                          [
                                                                          'reason'],
                                                                      style: TextStyle(
                                                                          color:
                                                                              textColor),
                                                                    ),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ));
                                                    })
                                                    .values
                                                    .toList(),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _cancelReason = 'others';
                                                  });
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(
                                                      media.width * 0.01),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        height:
                                                            media.height * 0.05,
                                                        width:
                                                            media.width * 0.05,
                                                        decoration: BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                                color:
                                                                    textColor,
                                                                width: 1.2)),
                                                        alignment:
                                                            Alignment.center,
                                                        child: (_cancelReason ==
                                                                'others')
                                                            ? Container(
                                                                height: media
                                                                        .width *
                                                                    0.03,
                                                                width: media
                                                                        .width *
                                                                    0.03,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color:
                                                                      textColor,
                                                                ),
                                                              )
                                                            : Container(),
                                                      ),
                                                      SizedBox(
                                                        width:
                                                            media.width * 0.05,
                                                      ),
                                                      Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              ['text_others'],
                                                          style: TextStyle(
                                                              color: textColor))
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              (_cancelReason == 'others')
                                                  ? Container(
                                                      margin:
                                                          EdgeInsets.fromLTRB(
                                                              0,
                                                              media.width *
                                                                  0.025,
                                                              0,
                                                              media.width *
                                                                  0.025),
                                                      padding: EdgeInsets.all(
                                                          media.width * 0.05),
                                                      width: media.width * 0.9,
                                                      decoration: BoxDecoration(
                                                          border: Border.all(
                                                              color:
                                                                  borderLines,
                                                              width: 1.2),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      12)),
                                                      child: TextField(
                                                        decoration: InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            hintText: languages[
                                                                    choosenLanguage]
                                                                [
                                                                'text_cancelRideReason'],
                                                            hintStyle: GoogleFonts.roboto(
                                                                color: textColor
                                                                    .withOpacity(
                                                                        0.4),
                                                                fontSize: media
                                                                        .width *
                                                                    twelve)),
                                                        style: TextStyle(
                                                            color: textColor),
                                                        maxLines: 4,
                                                        minLines: 2,
                                                        onChanged: (val) {
                                                          setState(() {
                                                            cancelReasonText =
                                                                val;
                                                          });
                                                        },
                                                      ),
                                                    )
                                                  : Container(),
                                              (_cancellingError != '')
                                                  ? Container(
                                                      padding: EdgeInsets.only(
                                                          top: media.width *
                                                              0.02,
                                                          bottom: media.width *
                                                              0.02),
                                                      width: media.width * 0.9,
                                                      child: Text(
                                                          _cancellingError,
                                                          style: GoogleFonts
                                                              .roboto(
                                                                  fontSize: media
                                                                          .width *
                                                                      twelve,
                                                                  color: Colors
                                                                      .red)))
                                                  : Container(),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Button(
                                                      color: page,
                                                      textcolor: buttonColor,
                                                      width: media.width * 0.39,
                                                      onTap: () async {
                                                        setState(() {
                                                          _isLoading = true;
                                                        });
                                                        if (_cancelReason !=
                                                            '') {
                                                          if (_cancelReason ==
                                                              'others') {
                                                            if (cancelReasonText !=
                                                                    '' &&
                                                                cancelReasonText
                                                                    .isNotEmpty) {
                                                              _cancellingError =
                                                                  '';
                                                              var val =
                                                                  await cancelRequestDriver(
                                                                      cancelReasonText);
                                                              if (val ==
                                                                  'logout') {
                                                                navigateLogout();
                                                              }
                                                              setState(() {
                                                                cancelRequest =
                                                                    false;
                                                              });
                                                            } else {
                                                              setState(() {
                                                                _cancellingError =
                                                                    languages[
                                                                            choosenLanguage]
                                                                        [
                                                                        'text_add_cancel_reason'];
                                                              });
                                                            }
                                                          } else {
                                                            var val =
                                                                await cancelRequestDriver(
                                                                    _cancelReason);
                                                            if (val ==
                                                                'logout') {
                                                              navigateLogout();
                                                            }
                                                            setState(() {
                                                              cancelRequest =
                                                                  false;
                                                            });
                                                          }
                                                        }
                                                        setState(() {
                                                          _isLoading = false;
                                                        });
                                                      },
                                                      text: languages[
                                                              choosenLanguage]
                                                          ['text_cancel']),
                                                  Button(
                                                      width: media.width * 0.39,
                                                      onTap: () {
                                                        setState(() {
                                                          cancelRequest = false;
                                                        });
                                                      },
                                                      text: languages[
                                                              choosenLanguage]
                                                          ['tex_dontcancel'])
                                                ],
                                              )
                                            ]),
                                          ),
                                        ],
                                      ),
                                    ))
                                  : Container(),

                              //loader
                              (state == '')
                                  ? const Positioned(top: 0, child: Loading())
                                  : Container(),

                              //delete account
                              (deleteAccount == true)
                                  ? Positioned(
                                      top: 0,
                                      child: Container(
                                        height: media.height * 1,
                                        width: media.width * 1,
                                        color: (isDarkTheme == true)
                                            ? textColor.withOpacity(0.2)
                                            : Colors.transparent
                                                .withOpacity(0.6),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: media.width * 0.9,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Container(
                                                      height:
                                                          media.height * 0.1,
                                                      width: media.width * 0.1,
                                                      decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: page),
                                                      child: InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              deleteAccount =
                                                                  false;
                                                            });
                                                          },
                                                          child: Icon(
                                                              Icons
                                                                  .cancel_outlined,
                                                              color:
                                                                  textColor))),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.all(
                                                  media.width * 0.05),
                                              width: media.width * 0.9,
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: page),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    languages[choosenLanguage]
                                                        ['text_delete_confirm'],
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.roboto(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  SizedBox(
                                                    height: media.width * 0.05,
                                                  ),
                                                  Button(
                                                      onTap: () async {
                                                        setState(() {
                                                          deleteAccount = false;
                                                          _isLoading = true;
                                                        });
                                                        var result =
                                                            await userDelete();
                                                        if (result ==
                                                            'success') {
                                                          setState(() {
                                                            Navigator.pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            const Login()),
                                                                (route) =>
                                                                    false);
                                                            userDetails.clear();
                                                          });
                                                        } else {
                                                          setState(() {
                                                            _isLoading = false;
                                                            deleteAccount =
                                                                true;
                                                          });
                                                        }
                                                        setState(() {
                                                          _isLoading = false;
                                                        });
                                                      },
                                                      text: languages[
                                                              choosenLanguage]
                                                          ['text_confirm'])
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ))
                                  : Container(),

                              //logout popup
                              (logout == true)
                                  ? Positioned(
                                      top: 0,
                                      child: Container(
                                        height: media.height * 1,
                                        width: media.width * 1,
                                        color: (isDarkTheme == true)
                                            ? textColor.withOpacity(0.2)
                                            : Colors.transparent
                                                .withOpacity(0.6),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: media.width * 0.9,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Container(
                                                      height:
                                                          media.height * 0.1,
                                                      width: media.width * 0.1,
                                                      decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: page),
                                                      child: InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              logout = false;
                                                            });
                                                          },
                                                          child: Icon(
                                                              Icons
                                                                  .cancel_outlined,
                                                              color:
                                                                  textColor))),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.all(
                                                  media.width * 0.05),
                                              width: media.width * 0.9,
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: page),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    languages[choosenLanguage]
                                                        ['text_confirmlogout'],
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.roboto(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  SizedBox(
                                                    height: media.width * 0.05,
                                                  ),
                                                  Button(
                                                      onTap: () async {
                                                        setState(() {
                                                          logout = false;
                                                          _isLoading = true;
                                                        });
                                                        var result =
                                                            await userLogout();
                                                        if (result ==
                                                            'success') {
                                                          setState(() {
                                                            Navigator.pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            const SignupMethod()),
                                                                (route) =>
                                                                    false);
                                                            userDetails.clear();
                                                          });
                                                        } else {
                                                          setState(() {
                                                            logout = true;
                                                            _isLoading = false;
                                                          });
                                                        }
                                                      },
                                                      text: languages[
                                                              choosenLanguage]
                                                          ['text_confirm'])
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ))
                                  : Container(),

                              //waiting time popup
                              (_showWaitingInfo == true)
                                  ? Positioned(
                                      top: 0,
                                      child: Container(
                                        height: media.height * 1,
                                        width: media.width * 1,
                                        color:
                                            Colors.transparent.withOpacity(0.6),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: media.width * 0.9,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Container(
                                                      height:
                                                          media.height * 0.1,
                                                      width: media.width * 0.1,
                                                      decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: page),
                                                      child: InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              _showWaitingInfo =
                                                                  false;
                                                            });
                                                          },
                                                          child: const Icon(Icons
                                                              .cancel_outlined))),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.all(
                                                  media.width * 0.05),
                                              width: media.width * 0.9,
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: page),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    languages[choosenLanguage]
                                                        ['text_waiting_time_1'],
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.roboto(
                                                        fontSize: media.width *
                                                            sixteen,
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  SizedBox(
                                                    height: media.width * 0.05,
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              [
                                                              'text_waiting_time_2'],
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      fourteen,
                                                              color:
                                                                  textColor)),
                                                      Text(
                                                          '${driverReq['free_waiting_time_in_mins_before_trip_start']} mins',
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      fourteen,
                                                              color: textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height: media.width * 0.05,
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              [
                                                              'text_waiting_time_3'],
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      fourteen,
                                                              color:
                                                                  textColor)),
                                                      Text(
                                                          '${driverReq['free_waiting_time_in_mins_after_trip_start']} mins',
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      fourteen,
                                                              color: textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ))
                                  : Container(),

                              //no internet
                              (internet == false)
                                  ? Positioned(
                                      top: 0,
                                      child: NoInternet(
                                        onTap: () async {
                                          internetTrue();
                                          var val = await getUserDetails();
                                          if (val == 'logout') {
                                            navigateLogout();
                                          }
                                          setState(() {});
                                        },
                                      ))
                                  : Container(),

                              //sos popup
                              (showSos == true)
                                  ? Positioned(
                                      top: 0,
                                      child: Container(
                                        height: media.height * 1,
                                        width: media.width * 1,
                                        color: (isDarkTheme == true)
                                            ? textColor.withOpacity(0.2)
                                            : Colors.transparent
                                                .withOpacity(0.6),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: media.width * 0.7,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          notifyCompleted =
                                                              false;
                                                          showSos = false;
                                                        });
                                                      },
                                                      child: Container(
                                                        height:
                                                            media.width * 0.1,
                                                        width:
                                                            media.width * 0.1,
                                                        decoration:
                                                            BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: page),
                                                        child: Icon(
                                                            Icons
                                                                .cancel_outlined,
                                                            color: textColor),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                height: media.width * 0.05,
                                              ),
                                              Container(
                                                padding: EdgeInsets.all(
                                                    media.width * 0.05),
                                                height: media.height * 0.5,
                                                width: media.width * 0.7,
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    color: page),
                                                child: SingleChildScrollView(
                                                    physics:
                                                        const BouncingScrollPhysics(),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        InkWell(
                                                          onTap: () async {
                                                            setState(() {
                                                              notifyCompleted =
                                                                  false;
                                                            });
                                                            var val =
                                                                await notifyAdmin();
                                                            if (val == true) {
                                                              setState(() {
                                                                notifyCompleted =
                                                                    true;
                                                              });
                                                            }
                                                          },
                                                          child: Container(
                                                            padding: EdgeInsets
                                                                .all(media
                                                                        .width *
                                                                    0.05),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      languages[
                                                                              choosenLanguage]
                                                                          [
                                                                          'text_notifyadmin'],
                                                                      style: GoogleFonts.roboto(
                                                                          fontSize: media.width *
                                                                              sixteen,
                                                                          color:
                                                                              textColor,
                                                                          fontWeight:
                                                                              FontWeight.w600),
                                                                    ),
                                                                    (notifyCompleted ==
                                                                            true)
                                                                        ? Container(
                                                                            padding:
                                                                                EdgeInsets.only(top: media.width * 0.01),
                                                                            child:
                                                                                Text(
                                                                              languages[choosenLanguage]['text_notifysuccess'],
                                                                              style: GoogleFonts.roboto(
                                                                                fontSize: media.width * twelve,
                                                                                color: const Color(0xff319900),
                                                                              ),
                                                                            ),
                                                                          )
                                                                        : Container()
                                                                  ],
                                                                ),
                                                                Icon(
                                                                    Icons
                                                                        .notification_add,
                                                                    color:
                                                                        textColor)
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        (sosData.isNotEmpty)
                                                            ? Column(
                                                                children: sosData
                                                                    .asMap()
                                                                    .map((i, value) {
                                                                      return MapEntry(
                                                                          i,
                                                                          InkWell(
                                                                            onTap:
                                                                                () {
                                                                              makingPhoneCall(sosData[i]['number'].toString().replaceAll(' ', ''));
                                                                            },
                                                                            child:
                                                                                Container(
                                                                              padding: EdgeInsets.all(media.width * 0.05),
                                                                              child: Row(
                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                children: [
                                                                                  Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: [
                                                                                      SizedBox(
                                                                                        width: media.width * 0.4,
                                                                                        child: Text(
                                                                                          sosData[i]['name'],
                                                                                          style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor, fontWeight: FontWeight.w600),
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(
                                                                                        height: media.width * 0.01,
                                                                                      ),
                                                                                      Text(
                                                                                        sosData[i]['number'],
                                                                                        style: GoogleFonts.roboto(
                                                                                          fontSize: media.width * twelve,
                                                                                          color: textColor,
                                                                                        ),
                                                                                      )
                                                                                    ],
                                                                                  ),
                                                                                  Icon(Icons.call, color: textColor)
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ));
                                                                    })
                                                                    .values
                                                                    .toList(),
                                                              )
                                                            : Container(
                                                                width: media
                                                                        .width *
                                                                    0.7,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                child: Text(
                                                                  languages[
                                                                          choosenLanguage]
                                                                      [
                                                                      'text_noDataFound'],
                                                                  style: GoogleFonts.roboto(
                                                                      fontSize:
                                                                          media.width *
                                                                              eighteen,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color:
                                                                          textColor),
                                                                ),
                                                              )
                                                      ],
                                                    )),
                                              )
                                            ]),
                                      ))
                                  : Container(),

                              //choose option for seeing location on map while having multiple stops
                              (_tripOpenMap == true)
                                  ? Positioned(
                                      top: 0,
                                      child: Container(
                                        height: media.height * 1,
                                        width: media.width * 1,
                                        color:
                                            Colors.transparent.withOpacity(0.6),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: media.width * 0.9,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _tripOpenMap = false;
                                                      });
                                                    },
                                                    child: Container(
                                                      height: media.width * 0.1,
                                                      width: media.width * 0.1,
                                                      decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: page),
                                                      child: const Icon(Icons
                                                          .cancel_outlined),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              height: media.width * 0.05,
                                            ),
                                            Container(
                                                width: media.width * 0.9,
                                                padding: EdgeInsets.all(
                                                    media.width * 0.05),
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    color: page),
                                                child: Column(
                                                  children: [
                                                    SizedBox(
                                                      width: media.width * 0.8,
                                                      child: Text(
                                                        languages[
                                                                choosenLanguage]
                                                            [
                                                            'text_choose_address_nav'],
                                                        style:
                                                            GoogleFonts.roboto(
                                                                fontSize: media
                                                                        .width *
                                                                    sixteen,
                                                                color:
                                                                    textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          media.width * 0.05,
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          media.height * 0.2,
                                                      child:
                                                          SingleChildScrollView(
                                                        physics:
                                                            const BouncingScrollPhysics(),
                                                        child: Column(
                                                          children: tripStops
                                                              .asMap()
                                                              .map((i, value) {
                                                                return MapEntry(
                                                                    i,
                                                                    InkWell(
                                                                      onTap:
                                                                          () {
                                                                        openMap(
                                                                            tripStops[i]['latitude'],
                                                                            tripStops[i]['longitude']);
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        // width: media.width*0.5,
                                                                        padding:
                                                                            EdgeInsets.all(media.width *
                                                                                0.025),
                                                                        child:
                                                                            Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            SizedBox(
                                                                              width: media.width * 0.6,
                                                                              child: Text(
                                                                                tripStops[i]['address'],
                                                                                style: GoogleFonts.roboto(fontSize: media.width * fourteen, color: textColor, fontWeight: FontWeight.w600),
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ),
                                                                            SizedBox(
                                                                              width: media.width * 00.05,
                                                                              child: Image.asset('assets/images/locationFind.png', width: media.width * 0.05, color: Colors.black, fit: BoxFit.contain),
                                                                            )
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ));
                                                              })
                                                              .values
                                                              .toList(),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ))
                                          ],
                                        ),
                                      ))
                                  : Container(),

                              (updateAvailable == true)
                                  ? Positioned(
                                      top: 0,
                                      child: Container(
                                        height: media.height * 1,
                                        width: media.width * 1,
                                        color:
                                            Colors.transparent.withOpacity(0.6),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                                width: media.width * 0.9,
                                                padding: EdgeInsets.all(
                                                    media.width * 0.05),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  color: page,
                                                ),
                                                child: Column(
                                                  children: [
                                                    SizedBox(
                                                        width:
                                                            media.width * 0.8,
                                                        child: Text(
                                                          languages[
                                                                  choosenLanguage]
                                                              [
                                                              'text_update_available'],
                                                          style: GoogleFonts.roboto(
                                                              fontSize:
                                                                  media.width *
                                                                      sixteen,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        )),
                                                    SizedBox(
                                                      height:
                                                          media.width * 0.05,
                                                    ),
                                                    Button(
                                                        onTap: () async {
                                                          if (platform ==
                                                              TargetPlatform
                                                                  .android) {
                                                            openBrowser(
                                                                'https://play.google.com/store/apps/details?id=${package.packageName}');
                                                          } else {
                                                            setState(() {
                                                              _isLoading = true;
                                                            });
                                                            var response =
                                                                await http.get(
                                                                    Uri.parse(
                                                                        'http://itunes.apple.com/lookup?bundleId=${package.packageName}'));
                                                            if (response
                                                                    .statusCode ==
                                                                200) {
                                                              openBrowser(jsonDecode(
                                                                          response
                                                                              .body)[
                                                                      'results'][0]
                                                                  [
                                                                  'trackViewUrl']);

                                                              // printWrapped(jsonDecode(response.body)['results'][0]['trackViewUrl']);
                                                            }

                                                            setState(() {
                                                              _isLoading =
                                                                  false;
                                                            });
                                                          }
                                                        },
                                                        text: 'Update')
                                                  ],
                                                ))
                                          ],
                                        ),
                                      ))
                                  : Container(),

                              //loader
                              (_isLoading == true)
                                  ? const Positioned(top: 0, child: Loading())
                                  : Container(),
                              //pickup marker
                              Positioned(
                                top: media.height * 1.5,
                                left: 100,
                                child: RepaintBoundary(
                                    key: iconKey,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                              image: AssetImage(
                                                  'assets/images/pickupmarker.png'),
                                              fit: BoxFit.contain)),
                                      height: 40,
                                      width: 40,
                                    )),
                              ),

                              //drop marker
                              Positioned(
                                top: media.height * 2.5,
                                left: 100,
                                child: (tripStops.isNotEmpty)
                                    ? Column(
                                        children: [
                                          Column(
                                            children: tripStops
                                                .asMap()
                                                .map((i, value) {
                                                  iconDropKeys[i] = 'Key_$i';
                                                  iconDropKeys[i] = GlobalKey();
                                                  return MapEntry(
                                                    i,
                                                    RepaintBoundary(
                                                        key: iconDropKeys[i],
                                                        child: Column(
                                                          children: [
                                                            (i <
                                                                    tripStops
                                                                            .length -
                                                                        1)
                                                                ? Container(
                                                                    padding: const EdgeInsets
                                                                            .only(
                                                                        bottom:
                                                                            5),
                                                                    child: Text(
                                                                      (i + 1)
                                                                          .toString(),
                                                                      style: GoogleFonts.roboto(
                                                                          fontSize: media.width *
                                                                              sixteen,
                                                                          fontWeight: FontWeight
                                                                              .w600,
                                                                          color:
                                                                              Colors.red),
                                                                    ),
                                                                  )
                                                                : Container(),
                                                            Container(
                                                              decoration: const BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  image: DecorationImage(
                                                                      image: AssetImage(
                                                                          'assets/images/dropmarker.png'),
                                                                      fit: BoxFit
                                                                          .contain)),
                                                              height: 40,
                                                              width: 40,
                                                            )
                                                          ],
                                                        )),
                                                  );
                                                })
                                                .values
                                                .toList(),
                                          ),
                                        ],
                                      )
                                    : RepaintBoundary(
                                        key: iconDropKey,
                                        child: Column(
                                          children: [
                                            // (tripStops.isNotEmpty) ?

                                            Container(
                                              decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  image: DecorationImage(
                                                      image: AssetImage(
                                                          'assets/images/dropmarker.png'),
                                                      fit: BoxFit.contain)),
                                              height: media.width * 0.1,
                                              width: media.width * 0.1,
                                            )
                                          ],
                                        )),
                              )
                            ],
                          ),
                        );
                      }),
                ),
              );
            }),
      ),
    );
  }

  double getBearing(LatLng begin, LatLng end) {
    double lat = (begin.latitude - end.latitude).abs();

    double lng = (begin.longitude - end.longitude).abs();

    if (begin.latitude < end.latitude && begin.longitude < end.longitude) {
      return vector.degrees(atan(lng / lat));
    } else if (begin.latitude >= end.latitude &&
        begin.longitude < end.longitude) {
      return (90 - vector.degrees(atan(lng / lat))) + 90;
    } else if (begin.latitude >= end.latitude &&
        begin.longitude >= end.longitude) {
      return vector.degrees(atan(lng / lat)) + 180;
    } else if (begin.latitude < end.latitude &&
        begin.longitude >= end.longitude) {
      return (90 - vector.degrees(atan(lng / lat))) + 270;
    }

    return -1;
  }

  animateCar(
      double fromLat, //Starting latitude

      double fromLong, //Starting longitude

      double toLat, //Ending latitude

      double toLong, //Ending longitude

      StreamSink<List<Marker>>
          mapMarkerSink, //Stream build of map to update the UI

      TickerProvider
          provider, //Ticker provider of the widget. This is used for animation

      GoogleMapController controller, //Google map controller of our widget

      markerid,
      icon,
      name,
      number) async {
    final double bearing =
        getBearing(LatLng(fromLat, fromLong), LatLng(toLat, toLong));

    dynamic carMarker;
    if (name == '' && number == '') {
      carMarker = Marker(
          markerId: MarkerId(markerid),
          position: LatLng(fromLat, fromLong),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          draggable: false);
    } else {
      carMarker = Marker(
          markerId: MarkerId(markerid),
          position: LatLng(fromLat, fromLong),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: number, snippet: name),
          flat: true,
          draggable: false);
    }

    myMarkers.add(carMarker);

    mapMarkerSink.add(Set<Marker>.from(myMarkers).toList());

    Tween<double> tween = Tween(begin: 0, end: 1);

    _animation = tween.animate(animationController)
      ..addListener(() async {
        myMarkers
            .removeWhere((element) => element.markerId == MarkerId(markerid));

        final v = _animation!.value;

        double lng = v * toLong + (1 - v) * fromLong;

        double lat = v * toLat + (1 - v) * fromLat;

        LatLng newPos = LatLng(lat, lng);

        //New marker location

        if (name == '' && number == '') {
          carMarker = Marker(
              markerId: MarkerId(markerid),
              position: newPos,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              flat: true,
              rotation: bearing,
              draggable: false);
        } else {
          carMarker = Marker(
              markerId: MarkerId(markerid),
              position: newPos,
              icon: icon,
              infoWindow: InfoWindow(title: number, snippet: name),
              anchor: const Offset(0.5, 0.5),
              flat: true,
              rotation: bearing,
              draggable: false);
        }

        //Adding new marker to our list and updating the google map UI.

        myMarkers.add(carMarker);

        mapMarkerSink.add(Set<Marker>.from(myMarkers).toList());
      });

    //Starting the animation

    animationController.forward();

    if (driverReq.isEmpty || driverReq['is_trip_start'] == 1) {
      controller.getVisibleRegion().then((value) {
        if (value.contains(myMarkers
            .firstWhere((element) => element.markerId == MarkerId(markerid))
            .position)) {
        } else {
          controller.animateCamera(CameraUpdate.newLatLng(center));
        }
      });
    }
    animationController = null;
  }
}

class OwnerCarImagecontainer extends StatelessWidget {
  final String imgurl;
  final String text;
  final Color color;
  final void Function()? ontap;
  const OwnerCarImagecontainer(
      {Key? key,
      required this.imgurl,
      required this.text,
      required this.ontap,
      required this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return InkWell(
      onTap: ontap,
      child: Container(
        padding: EdgeInsets.all(
          media.width * 0.01,
        ),
        width: media.width * 0.15,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                      image: AssetImage(imgurl), fit: BoxFit.contain)),
              height: media.width * 0.07,
              width: media.width * 0.15,
            ),
            Container(
              height: media.width * 0.03,
              width: media.width * 0.13,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: color,
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            )
          ],
        ),
      ),
    );
  }
}
