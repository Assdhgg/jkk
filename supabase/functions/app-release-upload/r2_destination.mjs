// R2's destination condition prevents overwriting an existing published APK.
// The build step runs before the SDK signs the request.
export function preventDestinationOverwrite(command) {
  command.middlewareStack.add(next => async args => {
    args.request.headers['cf-copy-destination-if-none-match'] = '*';
    return next(args);
  }, {step: 'build', name: 'r2PreventDestinationOverwrite'});
  return command;
}
