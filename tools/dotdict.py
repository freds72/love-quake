# helper dict
class dotdict(dict):
    def __getattr__(self, name):
        return self.get(name,None)
