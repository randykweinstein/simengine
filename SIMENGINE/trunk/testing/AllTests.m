function s = AllTests

s = Suite('All Tests');

% Pull in each of the other test suites
s.add(ReleaseCompileTests)
s.add(InternalCompileTests)

end