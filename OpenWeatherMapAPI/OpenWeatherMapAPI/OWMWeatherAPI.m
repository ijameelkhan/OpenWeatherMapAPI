//
//  OWMWeatherAPI.m
//  OpenWeatherMapAPI
//
//  Created by Adrian Bak on 20/6/13.
//  Copyright (c) 2013 Adrian Bak. All rights reserved.
//

#import "OWMWeatherAPI.h"
#import "AFJSONRequestOperation.h"

@interface OWMWeatherAPI () {
    NSString *_baseURL;
    NSString *_apiKey;
    NSString *_apiVersion;
    NSOperationQueue *_weatherQueue;
    
    OWMTemperature _currentTemperatureFormat;
}

@end

@implementation OWMWeatherAPI

- (instancetype) initWithAPIKey:(NSString *) apiKey {
    self = [super init];
    if (self) {
        _baseURL = @"http://api.openweathermap.org/data/";
        _apiKey  = apiKey;
        _apiVersion = @"2.5";
        
        _weatherQueue = [[NSOperationQueue alloc] init];
        _weatherQueue.name = @"OMWWeatherQueue";
        
        _currentTemperatureFormat = kOWMTempCelcius;
        
    }
    return self;
}

#pragma mark - private parts

- (void) setTemperatureFormat:(OWMTemperature) tempFormat {
    _currentTemperatureFormat = tempFormat;
}
- (OWMTemperature) temperatureFormat {
    return _currentTemperatureFormat;
}


+ (NSNumber *) tempToCelcius:(NSNumber *) tempKelvin
{
    return @(tempKelvin.floatValue - 273.15);
}

+ (NSNumber *) tempToFahrenheit:(NSNumber *) tempKelvin
{
    return @((tempKelvin.floatValue * 9/5) - 459.67);
}


- (NSNumber *) convertTemp:(NSNumber *) temp {
    if (_currentTemperatureFormat == kOWMTempCelcius) {
        return [OWMWeatherAPI tempToCelcius:temp];
    } else if (_currentTemperatureFormat == kOWMTempFahrenheit) {
        return [OWMWeatherAPI tempToFahrenheit:temp];
    } else {
        return temp;
    }
}

- (NSDate *) convertToDate:(NSNumber *) num {
    return [NSDate dateWithTimeIntervalSince1970:num.intValue];
}

/**
 * Recursivly change temperatures in result data
 **/
- (NSDictionary *) convertResult:(NSDictionary *) res {
    
    NSMutableDictionary *dic = [res mutableCopy];
    
    NSMutableDictionary *main = [[dic objectForKey:@"main"] mutableCopy];
    if (main) {
        main[@"temp"] = [self convertTemp:main[@"temp"]];
        main[@"temp_min"] = [self convertTemp:main[@"temp_min"]];
        main[@"temp_max"] = [self convertTemp:main[@"temp_max"]];
        
        dic[@"main"] = [main copy];
        
    }
    
    NSMutableDictionary *sys = [[dic objectForKey:@"sys"] mutableCopy];
    if (sys) {
        
        sys[@"sunrise"] = [self convertToDate: sys[@"sunrise"]];
        sys[@"sunset"] = [self convertToDate: sys[@"sunset"]];
        
        dic[@"sys"] = [sys copy];
    }
    
    
    NSMutableArray *list = [[dic objectForKey:@"list"] mutableCopy];
    if (list) {
        
        for (int i = 0; i < list.count; i++) {
            [list replaceObjectAtIndex:i withObject:[self convertResult: list[i]]];
        }
        
        dic[@"list"] = [list copy];
    }
    
    dic[@"dt"] = [self convertToDate:dic[@"dt"]];

    return [dic copy];
}

/**
 * Calls the web api, and converts the result. Then it calls the callback on the caller-queue
 **/
- (void) callMethod:(NSString *) method withCallback:( void (^)( NSError* error, NSDictionary *result ) )callback
{
    
    NSOperationQueue *callerQueue = [NSOperationQueue currentQueue];
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@&APPID=%@", _baseURL, _apiVersion, method, _apiKey];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {

        // callback on the caller queue
        NSDictionary *res = [self convertResult:JSON];
        [callerQueue addOperationWithBlock:^{
            callback(nil, res);
        }];

        
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {

        // callback on the caller queue
        [callerQueue addOperationWithBlock:^{
            callback(error, nil);
        }];
        
    }];
    [_weatherQueue addOperation:operation];
}

#pragma mark - public api

- (void) setApiVersion:(NSString *) version {
    _apiVersion = version;
}

- (NSString *) apiVersion {
    return _apiVersion;
}

#pragma mark current weather

-(void) currentWeatherByCityName:(NSString *) name
                    withCallback:( void (^)( NSError* error, NSDictionary *result ) )callback
{
    
    NSString *method = [NSString stringWithFormat:@"/weather?q=%@", name];
    [self callMethod:method withCallback:callback];
    
}

-(void) currentWeatherByCoordinate:(CLLocationCoordinate2D) coordinate
                      withCallback:( void (^)( NSError* error, NSDictionary *result ) )callback
{
    
    NSString *method = [NSString stringWithFormat:@"/weather?lat=%f,lon=%f",
                        coordinate.latitude, coordinate.longitude ];
    [self callMethod:method withCallback:callback];    
    
}

-(void) currentWeatherByCityId:(NSString *) cityId
                  withCallback:( void (^)( NSError* error, NSDictionary *result ) )callback
{
    NSString *method = [NSString stringWithFormat:@"/weather?id=%@", cityId];
    [self callMethod:method withCallback:callback];    
}


#pragma mark forcast

-(void) forecastWeatherByCityName:(NSString *) name
                    withCallback:( void (^)( NSError* error, NSDictionary *result ) )callback
{
    
    NSString *method = [NSString stringWithFormat:@"/forecast?q=%@", name];
    [self callMethod:method withCallback:callback];
    
}

-(void) forecastWeatherByCoordinate:(CLLocationCoordinate2D) coordinate
                      withCallback:( void (^)( NSError* error, NSDictionary *result ) )callback
{
    
    NSString *method = [NSString stringWithFormat:@"/forecast?lat=%f,lon=%f",
                        coordinate.latitude, coordinate.longitude ];
    [self callMethod:method withCallback:callback];
    
}

-(void) forecastWeatherByCityId:(NSString *) cityId
                  withCallback:( void (^)( NSError* error, NSDictionary *result ) )callback
{
    NSString *method = [NSString stringWithFormat:@"/forecast?id=%@", cityId];
    [self callMethod:method withCallback:callback];
}



@end
