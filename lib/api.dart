import 'package:algoritmik_f1/persistent_state.dart';

import 'cache.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'models/Constructors.dart';
import 'models/Driver.dart';
import 'models/Race.dart';


class ApiHelper {
  static final Uri _seasonUri = new Uri.https("ergast.com","/api/f1/" + new DateTime.now().year.toString() +".json");
  
  static Uri driverStandingsUri([String year="current"]) {
    return new Uri.http("ergast.com", "/api/f1/" + year + "/driverStandings.json");
  }

  static Uri constructorStandingsUri([String year="current"]) {
    return new Uri.http("ergast.com", "/api/f1/" + year + "/constructorStandings.json");
  }

  static Uri raceResultUri({String year, String round}) {
    return new Uri.http("ergast.com", "/api/f1/" + year + "/"+ round + "/results.json");
  }

  static Future<String> makeRequest(Uri uri) async {
    var httpClient = new HttpClient();
    var request = await httpClient.getUrl(uri);
    var response = await request.close();
    if (response.statusCode == HttpStatus.OK) {
      var json = await response.transform(utf8.decoder).join();
      if(uri == _seasonUri)
        CacheHelper.writeRaceCache(json);
      return json;
    } else {
      return 'Error getting IP address:\nHttp status ${response.statusCode}';
    }
  }

  static Future<String> getRaces() {
    return makeRequest(_seasonUri).then((res) => res);
  }

  static Future<Map> getDriverStandings([String year="current"]) { 
    return makeRequest(driverStandingsUri(year)).then((res) {
      var response = json.decode(res);
      List<DriverStandingModel> standingsList = new List();
      
      var standings = response["MRData"]["StandingsTable"]["StandingsLists"][0];

      var driverStandings = standings["DriverStandings"];
      
      for(var driver in driverStandings) {
        standingsList.add(
          new DriverStandingModel(
            new Driver.fromJson(driver["Driver"]),
            driver["position"],
            driver["points"],
            driver["wins"],          
          ),
        );
      }
      
      Map requestResponse = {
        "standings" : standingsList,
        "round" : standings["round"],
        "year" : standings["season"]
      };

      GlobalData.driverStandings.value = requestResponse;

      return requestResponse;
    });
  }
  
  static Future<Map> getConstructorStandings([String year="current"]) {
    return makeRequest(constructorStandingsUri(year)).then((res) {
      var response = json.decode(res);
      List<ConstructorStandingModel> standingsList = new List();

      var standings = response["MRData"]["StandingsTable"]["StandingsLists"][0];

      var constructorStandings = standings["ConstructorStandings"];

      for(var ctor in constructorStandings) {
        standingsList.add(
          new ConstructorStandingModel(
            new Constructor.fromJson(ctor["Constructor"]),
            ctor["position"],
            ctor["points"],
            ctor["wins"],   
          )
        );
      }
      
      Map requestResponse = {
        "standings" : standingsList,
        "round" : standings["round"],
        "year" : standings["season"]
      };

      return requestResponse;
    }).catchError((onError) {
      return "An Error Occured";
    });
  }

  static Future<Map> getRaceResultsByRound({String year="2018", String round}) {
    return makeRequest(raceResultUri(year: year, round: round)).then((res) {
      var response = json.decode(res);

      var results;

      try {
        results = response["MRData"]["RaceTable"]["Races"][0]["Results"];
      } catch (e) {
        throw new StateError("Race results are not ready yet");
      }

      List<RaceResult> raceResultList = new List();

      for (var result in results) {
        raceResultList.add(
          new RaceResult(
            number: result["number"],
            position: result["position"],
            points: result["points"],
            driver: DriverList.driver(driverEntry: result["Driver"]),
            constructor: ConstructorList.constructor(constructorEntry: result["Constructor"]),
            grid: result["grid"],
            laps: result["laps"],
            status: result["status"],
            time: result["Time"] != null ? result["Time"]["time"] : "Not Finished",
            fastestLapRank: result["FastestLap"] != null ? result["FastestLap"]["rank"] : "No time",
            fastestLapTime: result["FastestLap"] != null ? result["FastestLap"]["Time"]["time"] : "No time",
            avgSpeed: result["FastestLap"] != null ? result["FastestLap"]["AverageSpeed"]["speed"] + " Km/H" : "No time",
          )
        );
      }

      GlobalData.updateRaceResults(round, raceResultList);
    });
  }

}

