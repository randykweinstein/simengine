function e = simFailure (id, msg)
    simError('simex', id, ['Internal failure: ' msg ' Please contact ' ...
                        'support@simatratechnologies.com for ' ...
                        'assistance.']);
end